import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/events/html_message.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/background_audio_player.dart';
import '../../../utils/matrix_sdk_extensions/event_extension.dart';

class AudioPlayerWidget extends StatefulWidget {
  final Color color;
  final Color linkColor;
  final double fontSize;
  final Event event;

  static const int wavesCount = 40;

  const AudioPlayerWidget(
    this.event, {
    required this.color,
    required this.linkColor,
    required this.fontSize,
    super.key,
  });

  @override
  AudioPlayerState createState() => AudioPlayerState();
}

class AudioPlayerState extends State<AudioPlayerWidget> {
  BackgroundAudioPlayerState get _player => BackgroundAudioPlayer.of(context);

  bool get _isThisTrack => _player.isTrackLoaded(widget.event.eventId);
  bool get _isThisPlaying => _player.isTrackPlaying(widget.event.eventId);
  bool get _isThisPaused =>
      _isThisTrack && _player.status == BackgroundAudioStatus.paused;

  void _startAction() {
    if (_isThisTrack) {
      if (_isThisPlaying) {
        _player.pause();
      } else if (_isThisPaused) {
        _player.resume();
      } else {
        // Completed or idle but same track - replay
        _player.playFromEvent(widget.event);
      }
    } else {
      _player.playFromEvent(widget.event).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      });
    }
  }

  static const double buttonSize = 36;

  String? get _durationString {
    final durationInt = widget.event.content
        .tryGetMap<String, dynamic>('info')
        ?.tryGet<int>('duration');
    if (durationInt == null) return null;
    final duration = Duration(milliseconds: durationInt);
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  List<int>? _getWaveform() {
    final eventWaveForm = widget.event.content
        .tryGetMap<String, dynamic>('org.matrix.msc1767.audio')
        ?.tryGetList<int>('waveform');
    if (eventWaveForm == null || eventWaveForm.isEmpty) {
      return null;
    }
    while (eventWaveForm.length < AudioPlayerWidget.wavesCount) {
      for (var i = 0; i < eventWaveForm.length; i = i + 2) {
        eventWaveForm.insert(i, eventWaveForm[i]);
      }
    }
    var i = 0;
    final step = (eventWaveForm.length / AudioPlayerWidget.wavesCount).round();
    while (eventWaveForm.length > AudioPlayerWidget.wavesCount) {
      eventWaveForm.removeAt(i);
      i = (i + step) % AudioPlayerWidget.wavesCount;
    }
    return eventWaveForm.map((i) => i > 1024 ? 1024 : i).toList();
  }

  late final List<int>? _waveform;

  void _toggleSpeed() async {
    if (!_isThisTrack) return;
    await _player.cyclePlaybackRate();
  }

  @override
  void initState() {
    super.initState();
    _waveform = _getWaveform();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waveform = _waveform;
    final player = _player;

    final textColor = widget.color;
    final linkColor = widget.linkColor;
    final fileDescription = widget.event.fileDescription;

    // Use ValueListenableBuilders to reactively update UI from the background player
    return ValueListenableBuilder<AudioTrackInfo?>(
      valueListenable: player.trackNotifier,
      builder: (context, currentTrack, _) {
        final isThisTrack = currentTrack?.id == widget.event.eventId;

        return ValueListenableBuilder<BackgroundAudioStatus>(
          valueListenable: player.statusNotifier,
          builder: (context, status, _) {
            final isPlaying =
                isThisTrack && status == BackgroundAudioStatus.playing;
            final isLoading =
                isThisTrack && status == BackgroundAudioStatus.loading;

            return ValueListenableBuilder<Duration>(
              valueListenable: player.positionNotifier,
              builder: (context, position, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: player.durationNotifier,
                  builder: (context, duration, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: player.playbackRateNotifier,
                      builder: (context, playbackRate, _) {
                        final currentPosition = isThisTrack
                            ? position.inMilliseconds.toDouble()
                            : 0.0;
                        final maxPosition =
                            isThisTrack && duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1.0;

                        final statusText =
                            isThisTrack && position != Duration.zero
                            ? '${position.inMinutes.toString().padLeft(2, '0')}:${(position.inSeconds % 60).toString().padLeft(2, '0')}'
                            : _durationString ?? '00:00';

                        final wavePosition = maxPosition > 0
                            ? (currentPosition / maxPosition) *
                                  AudioPlayerWidget.wavesCount
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: FluffyThemes.columnWidth,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    SizedBox(
                                      width: buttonSize,
                                      height: buttonSize,
                                      child: isLoading
                                          ? CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: widget.color,
                                            )
                                          : InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(64),
                                              onLongPress: () => widget.event
                                                  .saveFile(context),
                                              onTap: _startAction,
                                              child: Material(
                                                color: widget.color.withAlpha(
                                                  64,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(64),
                                                child: Icon(
                                                  isPlaying
                                                      ? Icons.pause_outlined
                                                      : Icons
                                                            .play_arrow_outlined,
                                                  color: widget.color,
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          if (waveform != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16.0,
                                                  ),
                                              child: Row(
                                                children: [
                                                  for (
                                                    var i = 0;
                                                    i <
                                                        AudioPlayerWidget
                                                            .wavesCount;
                                                    i++
                                                  )
                                                    Expanded(
                                                      child: Container(
                                                        height: 32,
                                                        alignment:
                                                            Alignment.center,
                                                        child: Container(
                                                          margin:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 1,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                i < wavePosition
                                                                ? widget.color
                                                                : widget.color
                                                                      .withAlpha(
                                                                        128,
                                                                      ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  64,
                                                                ),
                                                          ),
                                                          height:
                                                              32 *
                                                              (waveform[i] /
                                                                  1024),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          SizedBox(
                                            height: 32,
                                            child: Slider(
                                              thumbColor:
                                                  widget.event.senderId ==
                                                      widget
                                                          .event
                                                          .room
                                                          .client
                                                          .userID
                                                  ? theme.colorScheme.onPrimary
                                                  : theme.colorScheme.primary,
                                              activeColor: waveform == null
                                                  ? widget.color
                                                  : Colors.transparent,
                                              inactiveColor: waveform == null
                                                  ? widget.color.withAlpha(128)
                                                  : Colors.transparent,
                                              max: maxPosition,
                                              value: currentPosition.clamp(
                                                0.0,
                                                maxPosition,
                                              ),
                                              onChanged: (position) {
                                                if (!isThisTrack) {
                                                  _startAction();
                                                } else {
                                                  player.seekToMs(position);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: widget.color,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedCrossFade(
                                      firstChild: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: Icon(
                                          Icons.mic_none_outlined,
                                          color: widget.color,
                                        ),
                                      ),
                                      secondChild: Material(
                                        color: widget.color.withAlpha(64),
                                        borderRadius: BorderRadius.circular(
                                          AppConfig.borderRadius,
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            AppConfig.borderRadius,
                                          ),
                                          onTap: _toggleSpeed,
                                          child: SizedBox(
                                            width: 32,
                                            height: 20,
                                            child: Center(
                                              child: Text(
                                                '${isThisTrack ? playbackRate : 1.0}x',
                                                style: TextStyle(
                                                  color: widget.color,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      crossFadeState: !isThisTrack
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      duration: FluffyThemes.animationDuration,
                                    ),
                                  ],
                                ),
                              ),
                              if (fileDescription !=
                                  widget.event.plaintextBody) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    widget.event.plaintextBody,
                                    textScaleFactor: MediaQuery.textScalerOf(
                                      context,
                                    ).scale(1),
                                    style: TextStyle(
                                      color: widget.color,
                                      fontSize: widget.fontSize,
                                    ),
                                  ),
                                ),
                              ],
                              if (fileDescription != null &&
                                  !widget.event.isRichFileDescription) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Linkify(
                                    text: fileDescription,
                                    textScaleFactor: MediaQuery.textScalerOf(
                                      context,
                                    ).scale(1),
                                    style: TextStyle(
                                      color: widget.color,
                                      fontSize: widget.fontSize,
                                    ),
                                    options: const LinkifyOptions(
                                      humanize: false,
                                    ),
                                    linkStyle: TextStyle(
                                      color: widget.linkColor,
                                      fontSize: widget.fontSize,
                                      decoration: TextDecoration.underline,
                                      decorationColor: widget.linkColor,
                                    ),
                                    onOpen: (url) => UrlLauncher(
                                      context,
                                      url.url,
                                    ).launchUrl(),
                                  ),
                                ),
                              ],
                              if (fileDescription != null &&
                                  widget.event.isRichFileDescription) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: HtmlMessage(
                                    html: fileDescription,
                                    textColor: textColor,
                                    room: widget.event.room,
                                    fontSize:
                                        AppSettings.fontSizeFactor.value *
                                        AppSettings.messageFontSize.value,
                                    linkStyle: TextStyle(
                                      color: linkColor,
                                      fontSize:
                                          AppSettings.fontSizeFactor.value *
                                          AppSettings.messageFontSize.value,
                                      decoration: TextDecoration.underline,
                                      decorationColor: linkColor,
                                    ),
                                    onOpen: (url) => UrlLauncher(
                                      context,
                                      url.url,
                                    ).launchUrl(),
                                    onCopy: () {
                                      Clipboard.setData(
                                        ClipboardData(text: fileDescription),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            L10n.of(context).copiedToClipboard,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
