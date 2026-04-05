import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:matrix/matrix.dart';
import 'package:opus_caf_converter_dart/opus_caf_converter_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:extera_next/generated/l10n/l10n.dart';

enum BackgroundAudioStatus { idle, loading, playing, paused, completed }

class AudioTrackInfo {
  final String id;
  final String title;
  final String? subtitle;
  final String? mxcUrl;
  final Duration? duration;
  final List<int>? waveform;
  final String? mimeType;

  const AudioTrackInfo({
    required this.id,
    required this.title,
    this.subtitle,
    this.mxcUrl,
    this.duration,
    this.waveform,
    this.mimeType,
  });

  AudioTrackInfo copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? mxcUrl,
    Duration? duration,
    List<int>? waveform,
    String? mimeType,
  }) {
    return AudioTrackInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      mxcUrl: mxcUrl ?? this.mxcUrl,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
      mimeType: mimeType ?? this.mimeType,
    );
  }
}

class BackgroundAudioPlayer extends StatefulWidget {
  final Widget child;

  const BackgroundAudioPlayer({required this.child, super.key});

  @override
  BackgroundAudioPlayerState createState() => BackgroundAudioPlayerState();

  static BackgroundAudioPlayerState of(BuildContext context) =>
      Provider.of<BackgroundAudioPlayerState>(context, listen: false);
}

class BackgroundAudioPlayerState extends State<BackgroundAudioPlayer>
    with WidgetsBindingObserver {
  AudioPlayer? _audioPlayer;
  AudioPlayer get audioPlayer =>
      _audioPlayer ??= AudioPlayer(playerId: 'background_audio_player');

  Event? _playingEvent;

  BackgroundAudioStatus _status = BackgroundAudioStatus.idle;
  AudioTrackInfo? _currentTrack;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackRate = 1.0;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  final ValueNotifier<BackgroundAudioStatus> statusNotifier = ValueNotifier(
    BackgroundAudioStatus.idle,
  );
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<AudioTrackInfo?> trackNotifier = ValueNotifier(null);
  final ValueNotifier<double> playbackRateNotifier = ValueNotifier(1.0);

  BackgroundAudioStatus get status => _status;
  AudioTrackInfo? get currentTrack => _currentTrack;
  Duration get position => _position;
  Duration get duration => _duration;
  double get playbackRate => _playbackRate;
  bool get isPlaying => _status == .playing;
  bool get isPaused => _status == .paused;
  bool get isIdle => _status == .idle;
  bool get hasTrack => _currentTrack != null;
  Event? get playingEvent => _playingEvent;

  String get positionString => _formatDuration(_position);

  String get durationString => _formatDuration(_duration);

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudioPlayerListeners();
  }

  void _initAudioPlayerListeners() {
    _positionSub = audioPlayer.onPositionChanged.listen((pos) {
      _position = pos;
      positionNotifier.value = pos;
    });

    _durationSub = audioPlayer.onDurationChanged.listen((dur) {
      if (dur == Duration.zero) return;
      _duration = dur;
      durationNotifier.value = dur;
      if (_currentTrack != null && _currentTrack!.duration == null) {
        _currentTrack = _currentTrack!.copyWith(duration: dur);
        trackNotifier.value = _currentTrack;
      }
    });

    _stateSub = audioPlayer.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _updateStatus(BackgroundAudioStatus.playing);
          break;
        case PlayerState.paused:
          _updateStatus(BackgroundAudioStatus.paused);
          break;
        case PlayerState.stopped:
          _updateStatus(BackgroundAudioStatus.idle);
          break;
        case PlayerState.completed:
          _updateStatus(BackgroundAudioStatus.completed);
          _onPlaybackCompleted();
          break;
        case PlayerState.disposed:
          _updateStatus(BackgroundAudioStatus.idle);
          break;
      }
    });
  }

  void _updateStatus(BackgroundAudioStatus newStatus) {
    _status = newStatus;
    statusNotifier.value = newStatus;
  }

  void _onPlaybackCompleted() {
    _position = Duration.zero;
    positionNotifier.value = Duration.zero;
    _playingEvent = null;
  }

  /// Play an audio message from a Matrix event.
  ///
  /// Downloads and decrypts the attachment if needed, then starts playback.
  Future<void> playFromEvent(Event event, {Client? client}) async {
    final effectiveClient = client ?? event.room.client;

    // If the same track is already loaded and paused, just resume
    if (_currentTrack?.id == event.eventId && isPaused) {
      await resume();
      return;
    }

    if (_status == .playing || _status == .paused) {
      await stop();
    }

    final info = event.content.tryGetMap<String, dynamic>('info');
    final audioInfo = event.content.tryGetMap<String, dynamic>(
      'org.matrix.msc1767.audio',
    );
    final durationMs = info?.tryGet<int>('duration');
    final waveform = audioInfo?.tryGetList<int>('waveform');
    final mimeType = info?.tryGet<String>('mimetype');

    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final roomName = event.room.getLocalizedDisplayname();

    _currentTrack = AudioTrackInfo(
      id: event.eventId,
      title:
          event.content.tryGet<String>('filename') ??
          L10n.of(context).audioMessage,
      subtitle: senderName == roomName ? senderName : '$senderName • $roomName',
      mxcUrl: event.attachmentMxcUrl?.toString(),
      duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      waveform: waveform,
      mimeType: mimeType,
    );
    trackNotifier.value = _currentTrack;
    _duration = _currentTrack!.duration ?? Duration.zero;
    durationNotifier.value = _duration;
    _position = Duration.zero;
    positionNotifier.value = Duration.zero;

    _playingEvent = event;

    _updateStatus(BackgroundAudioStatus.loading);

    try {
      if (audioPlayer.state == .disposed) {
        _audioPlayer = AudioPlayer(playerId: 'background_audio_player');
      }

      if (!kIsWeb) {
        final matrixFile = await event.downloadAndDecryptAttachment();
        final tempDir = await getTemporaryDirectory();
        final fileName = Uri.encodeComponent(
          event.attachmentOrThumbnailMxcUrl()!.pathSegments.last,
        );
        var file = File('${tempDir.path}/${fileName}_${matrixFile.name}');
        await file.writeAsBytes(matrixFile.bytes);

        // Convert ogg to caf on iOS
        if (Platform.isIOS &&
            matrixFile.mimeType.toLowerCase() == 'audio/ogg') {
          Logs().v('Convert ogg audio file for iOS...');
          final convertedFile = File('${file.path}.caf');
          if (await convertedFile.exists() == false) {
            OpusCaf().convertOpusToCaf(file.path, convertedFile.path);
          }
          file = convertedFile;
        }

        await audioPlayer.play(
          DeviceFileSource(file.path, mimeType: matrixFile.mimeType),
        );
      } else {
        final downloadUrl = (await event.attachmentMxcUrl?.getDownloadUri(
          effectiveClient,
        )).toString();
        await audioPlayer.play(UrlSource(downloadUrl));
      }
    } catch (e, s) {
      Logs().e('BackgroundAudioPlayer: Failed to play audio', e, s);
      _updateStatus(BackgroundAudioStatus.idle);
      _currentTrack = null;
      trackNotifier.value = null;
      rethrow;
    }
  }

  Future<void> playFromUrl(
    String url, {
    String? title,
    String? subtitle,
    String? id,
    String? mimeType,
  }) async {
    if (_status == .playing || _status == .paused) {
      await stop();
    }

    _currentTrack = AudioTrackInfo(
      id: id ?? url,
      title: title ?? 'Audio',
      subtitle: subtitle,
      mxcUrl: url,
      mimeType: mimeType,
    );
    trackNotifier.value = _currentTrack;
    _updateStatus(.loading);

    try {
      await audioPlayer.play(UrlSource(url));
    } catch (e, s) {
      Logs().e('BackgroundAudioPlayer: Failed to play from URL', e, s);
      _updateStatus(.idle);
      _currentTrack = null;
      trackNotifier.value = null;
      rethrow;
    }
  }

  Future<void> playFromFile(
    String filePath, {
    String? title,
    String? subtitle,
    String? id,
    String? mimeType,
  }) async {
    if (_status == .playing || _status == .paused) {
      await stop();
    }

    _currentTrack = AudioTrackInfo(
      id: id ?? filePath,
      title: title ?? 'Audio',
      subtitle: subtitle,
      mimeType: mimeType,
    );
    trackNotifier.value = _currentTrack;
    _updateStatus(.loading);

    try {
      await audioPlayer.play(DeviceFileSource(filePath, mimeType: mimeType));
    } catch (e, s) {
      Logs().e('BackgroundAudioPlayer: Failed to play from file', e, s);
      _updateStatus(.idle);
      _currentTrack = null;
      trackNotifier.value = null;
      rethrow;
    }
  }

  Future<void> pause() async {
    if (_status == .playing) {
      await audioPlayer.pause();
    }
  }

  Future<void> resume() async {
    if (_status == .paused) {
      await audioPlayer.resume();
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else if (isPaused) {
      await resume();
    }
  }

  Future<void> stop() async {
    await audioPlayer.stop();
    await audioPlayer.seek(.zero);
    _position = .zero;
    positionNotifier.value = .zero;
    _currentTrack = null;
    trackNotifier.value = null;
    _updateStatus(.idle);
  }

  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
    _position = position;
    positionNotifier.value = position;
  }

  Future<void> seekToMs(double milliseconds) async {
    await seek(Duration(milliseconds: milliseconds.round()));
  }

  Future<void> setPlaybackRate(double rate) async {
    await audioPlayer.setPlaybackRate(rate);
    _playbackRate = rate;
    playbackRateNotifier.value = rate;
  }

  Future<void> cyclePlaybackRate() async {
    switch (_playbackRate) {
      case 1.0:
        await setPlaybackRate(1.25);
        break;
      case 1.25:
        await setPlaybackRate(1.5);
        break;
      case 1.5:
        await setPlaybackRate(2.0);
        break;
      case 2.0:
        await setPlaybackRate(0.5);
        break;
      case 0.5:
      default:
        await setPlaybackRate(1.0);
        break;
    }
  }

  bool isTrackLoaded(String trackId) => _currentTrack?.id == trackId;

  bool isTrackPlaying(String trackId) =>
      _currentTrack?.id == trackId && isPlaying;

  String _formatDuration(Duration d) {
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    audioPlayer.release();
    audioPlayer.dispose();
    statusNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    trackNotifier.dispose();
    playbackRateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider(create: (_) => this, child: widget.child);
  }
}
