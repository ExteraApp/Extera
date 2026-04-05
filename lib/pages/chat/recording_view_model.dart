import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'events/audio_player.dart';

enum RecordingMode { audio, video }

class RecordingViewModel extends StatefulWidget {
  final Widget Function(BuildContext, RecordingViewModelState) builder;

  const RecordingViewModel({required this.builder, super.key});

  @override
  RecordingViewModelState createState() => RecordingViewModelState();
}

class RecordingViewModelState extends State<RecordingViewModel>
    with WidgetsBindingObserver {
  Timer? _recorderSubscription;
  Duration duration = Duration.zero;

  bool isSending = false;

  bool get isRecording => _audioRecorder != null || _isVideoRecording;

  // Audio recording
  AudioRecorder? _audioRecorder;
  final List<double> amplitudeTimeline = [];

  // Video recording
  CameraController? cameraController;
  bool _isVideoRecording = false;
  bool _isCameraInitialized = false;
  bool get isCameraInitialized => _isCameraInitialized;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 1; // Default to front camera

  RecordingMode _recordingMode = RecordingMode.audio;
  RecordingMode get recordingMode => _recordingMode;

  String? fileName;

  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle for camera
    if (cameraController != null && cameraController!.value.isInitialized) {
      if (state == AppLifecycleState.inactive) {
        _disposeCamera();
      } else if (state == AppLifecycleState.resumed) {
        if (_isVideoRecording) {
          // Camera was disposed while recording, cancel
          cancel();
        }
      }
    }
  }

  void setRecordingMode(RecordingMode mode) {
    if (!isRecording) {
      setState(() {
        _recordingMode = mode;
      });
    }
  }

  // ==================== Audio Recording ====================

  Future<void> startRecording(Room room) async {
    if (_recordingMode == RecordingMode.video) {
      await startVideoRecording(room);
      return;
    }
    await _startAudioRecording(room);
  }

  Future<void> _startAudioRecording(Room room) async {
    room.client.getConfig(); // Preload server file configuration.
    if (PlatformInfos.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt < 19) {
        showOkAlertDialog(
          context: context,
          title: L10n.of(context).unsupportedAndroidVersion,
          message: L10n.of(context).unsupportedAndroidVersionLong,
          okLabel: L10n.of(context).close,
        );
        return;
      }
    }

    if (await AudioRecorder().hasPermission() == false) return;

    final audioRecorder = _audioRecorder ??= AudioRecorder();
    setState(() {});

    try {
      final codec = kIsWeb
          ? AudioEncoder.wav
          : await audioRecorder.isEncoderSupported(AudioEncoder.opus)
          ? AudioEncoder.opus
          : AudioEncoder.aacLc;
      fileName =
          'voice_message_${DateTime.now().millisecondsSinceEpoch}.${codec.fileExtension}';
      String? path;
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        path = path_lib.join(tempDir.path, fileName);
      }

      final result = await audioRecorder.hasPermission();
      if (result != true) {
        showOkAlertDialog(
          context: context,
          title: L10n.of(context).oopsSomethingWentWrong,
          message: L10n.of(context).noPermission,
        );
        return;
      }
      await WakelockPlus.enable();

      await audioRecorder.start(
        RecordConfig(
          bitRate: AppSettings.audioRecordingBitRate.value,
          sampleRate: AppSettings.audioRecordingSamplingRate.value,
          numChannels: AppSettings.audioRecordingNumChannels.value,
          autoGain: AppSettings.audioRecordingAutoGain.value,
          echoCancel: AppSettings.audioRecordingEchoCancel.value,
          noiseSuppress: AppSettings.audioRecordingNoiseSuppress.value,
          encoder: codec,
        ),
        path: path ?? '',
      );
      setState(() => duration = Duration.zero);
      _subscribeAudio();
    } catch (e, s) {
      Logs().w('Unable to start voice message recording', e, s);
      showOkAlertDialog(
        context: context,
        title: L10n.of(context).oopsSomethingWentWrong,
        message: e.toString(),
      );
      setState(_reset);
    }
  }

  void _subscribeAudio() {
    _recorderSubscription?.cancel();
    _recorderSubscription = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      final amplitude = await _audioRecorder!.getAmplitude();
      var value = 100 + amplitude.current * 2;
      value = value < 1 ? 1 : value;
      amplitudeTimeline.add(value);
      setState(() {
        duration += const Duration(milliseconds: 100);
      });
    });
  }

  // ==================== Video Recording ====================

  Future<void> _initCamera() async {
    try {
      _cameras ??= await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        Logs().w('No cameras available');
        return;
      }

      // Prefer front camera (index 1), fallback to first available
      if (_currentCameraIndex >= _cameras!.length) {
        _currentCameraIndex = 0;
      }

      final camera = _cameras![_currentCameraIndex];
      cameraController = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: true,
        fps: 30,
      );

      await cameraController!.initialize();
      _isCameraInitialized = true;
      if (mounted) setState(() {});
    } catch (e, s) {
      Logs().w('Unable to initialize camera', e, s);
      _isCameraInitialized = false;
    }
  }

  Future<void> _disposeCamera() async {
    if (cameraController != null) {
      if (cameraController!.value.isRecordingVideo) {
        try {
          await cameraController!.stopVideoRecording();
        } catch (_) {}
      }
      await cameraController!.dispose();
      cameraController = null;
      _isCameraInitialized = false;
    }
  }

  bool _isSwitchingCamera = false;
  bool get isSwitchingCamera => _isSwitchingCamera;

  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    if (_isSwitchingCamera) return;

    _isSwitchingCamera = true;
    setState(() {});

    try {
      final nextIndex = (_currentCameraIndex + 1) % _cameras!.length;
      final newCamera = _cameras![nextIndex];

      if (_isVideoRecording && cameraController != null) {
        // Save reference to old controller, then detach from UI immediately
        final oldController = cameraController!;
        cameraController = null;
        _isCameraInitialized = false;
        if (mounted) setState(() {}); // UI now shows loading spinner

        // Stop recording and dispose old controller safely
        try {
          await oldController.stopVideoRecording();
        } catch (_) {}
        await oldController.dispose();

        // Create and initialize new controller
        final newController = CameraController(
          newCamera,
          ResolutionPreset.medium,
          enableAudio: true,
        );
        await newController.initialize();
        _currentCameraIndex = nextIndex;

        // Attach new controller to UI
        cameraController = newController;
        _isCameraInitialized = true;
        if (mounted) setState(() {}); // UI now shows new camera preview

        // Start recording on new camera
        await cameraController!.startVideoRecording();
      } else {
        _currentCameraIndex = nextIndex;
        // Detach from UI first
        final oldController = cameraController;
        cameraController = null;
        _isCameraInitialized = false;
        if (mounted) setState(() {});

        // Dispose old
        if (oldController != null) {
          await oldController.dispose();
        }

        // Init new
        await _initCamera();
      }
    } catch (e, s) {
      Logs().w('Failed to switch camera', e, s);
    } finally {
      _isSwitchingCamera = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> startVideoRecording(Room room) async {
    room.client.getConfig(); // Preload server file configuration.
    if (PlatformInfos.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt < 21) {
        showOkAlertDialog(
          context: context,
          title: L10n.of(context).unsupportedAndroidVersion,
          message: L10n.of(context).unsupportedAndroidVersionLong,
          okLabel: L10n.of(context).close,
        );
        return;
      }
    }

    try {
      await _initCamera();
      if (!_isCameraInitialized || cameraController == null) {
        showOkAlertDialog(
          context: context,
          title: L10n.of(context).oopsSomethingWentWrong,
          message: 'Could not initialize camera.',
        );
        return;
      }

      await WakelockPlus.enable();
      await cameraController!.startVideoRecording();

      fileName = 'video_note_${DateTime.now().millisecondsSinceEpoch}.mp4';

      _isVideoRecording = true;
      setState(() => duration = Duration.zero);
      _subscribeVideo();
    } catch (e, s) {
      Logs().w('Unable to start video note recording', e, s);
      showOkAlertDialog(
        context: context,
        title: L10n.of(context).oopsSomethingWentWrong,
        message: e.toString(),
      );
      setState(_reset);
    }
  }

  void _subscribeVideo() {
    _recorderSubscription?.cancel();
    _recorderSubscription = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) {
      setState(() {
        duration += const Duration(milliseconds: 100);
      });

      // Auto-stop at 60 seconds like Telegram
      if (duration.inSeconds >= 60) {
        _recorderSubscription?.cancel();
      }
    });
  }

  // ==================== Common ====================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reset();
    super.dispose();
  }

  void _reset() {
    WakelockPlus.disable();
    _recorderSubscription?.cancel();

    // Audio cleanup
    _audioRecorder?.stop();
    _audioRecorder = null;

    // Video cleanup
    _isVideoRecording = false;
    _disposeCamera();

    isSending = false;
    fileName = null;
    duration = Duration.zero;
    amplitudeTimeline.clear();
    isPaused = false;
  }

  void cancel() {
    setState(() {
      _reset();
    });
  }

  void pause() {
    if (_recordingMode == RecordingMode.video) {
      cameraController?.pauseVideoRecording();
    } else {
      _audioRecorder?.pause();
    }
    _recorderSubscription?.cancel();
    setState(() {
      isPaused = true;
    });
  }

  void resume() {
    if (_recordingMode == RecordingMode.video) {
      cameraController?.resumeVideoRecording();
      _subscribeVideo();
    } else {
      _audioRecorder?.resume();
      _subscribeAudio();
    }
    setState(() {
      isPaused = false;
    });
  }

  void stopAndSend(
    Future<void> Function(
      String path,
      int duration,
      List<int> waveform,
      String fileName,
    )
    onSend,
  ) async {
    if (_recordingMode == RecordingMode.video) {
      await _stopAndSendVideo(onSend);
    } else {
      await _stopAndSendAudio(onSend);
    }
  }

  Future<void> _stopAndSendAudio(
    Future<void> Function(
      String path,
      int duration,
      List<int> waveform,
      String fileName,
    )
    onSend,
  ) async {
    _recorderSubscription?.cancel();
    final path = await _audioRecorder?.stop();

    if (path == null) throw ('Recording failed!');
    const waveCount = AudioPlayerWidget.wavesCount;
    final step = amplitudeTimeline.length < waveCount
        ? 1
        : (amplitudeTimeline.length / waveCount).round();
    final waveform = <int>[];
    for (var i = 0; i < amplitudeTimeline.length; i += step) {
      waveform.add((amplitudeTimeline[i] / 100 * 1024).round());
    }

    setState(() {
      isSending = true;
    });
    try {
      await onSend(path, duration.inMilliseconds, waveform, fileName!);
    } catch (e, s) {
      Logs().e('Unable to send voice message', e, s);
      setState(() {
        isSending = false;
      });
      return;
    }

    cancel();
  }

  Future<void> stopAndSendVideo(
    Future<void> Function(String path, int duration, String fileName)
    onVideoSend,
  ) async {
    await _stopAndSendVideoWithCallback(onVideoSend);
  }

  Future<void> _stopAndSendVideo(
    Future<void> Function(
      String path,
      int duration,
      List<int> waveform,
      String fileName,
    )
    onSend,
  ) async {
    // This is called from the generic stopAndSend - wrap it
    await _stopAndSendVideoWithCallback((path, duration, fileName) async {
      await onSend(path, duration, [], fileName);
    });
  }

  Future<void> _stopAndSendVideoWithCallback(
    Future<void> Function(String path, int duration, String fileName)
    onVideoSend,
  ) async {
    _recorderSubscription?.cancel();

    if (cameraController == null || !cameraController!.value.isRecordingVideo) {
      throw ('Video recording failed!');
    }

    setState(() {
      isSending = true;
    });

    try {
      final xFile = await cameraController!.stopVideoRecording();
      _isVideoRecording = false;

      // Compress video to square 1:1 aspect ratio
      var finalPath = xFile.path;
      try {
        final mediaInfo = await VideoCompress.compressVideo(
          xFile.path,
          quality: VideoQuality.MediumQuality,
          includeAudio: true,
        );
        if (mediaInfo?.file != null) {
          finalPath = mediaInfo!.file!.path;
        }
      } catch (e, s) {
        Logs().w('Video compression failed, using original', e, s);
      }

      await onVideoSend(finalPath, duration.inMilliseconds, fileName!);
    } catch (e, s) {
      Logs().e('Unable to send video note', e, s);
      setState(() {
        isSending = false;
      });
      return;
    }

    cancel();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, this);
}

extension on AudioEncoder {
  String get fileExtension {
    switch (this) {
      case AudioEncoder.aacLc:
      case AudioEncoder.aacEld:
      case AudioEncoder.aacHe:
        return 'm4a';
      case AudioEncoder.opus:
        return 'ogg';
      case AudioEncoder.wav:
        return 'wav';
      case AudioEncoder.amrNb:
      case AudioEncoder.amrWb:
      case AudioEncoder.flac:
      case AudioEncoder.pcm16bits:
        throw UnsupportedError('Not yet used');
    }
  }
}
