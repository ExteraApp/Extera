import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/widgets/background_audio_player.dart';

/// A Material 3 mini audio player bar.
///
/// Displays when audio is playing/paused. Uses M3 surface tones,
/// FilledIconButton / IconButton.filledTonal, and proper elevation.
class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = BackgroundAudioPlayer.of(context);

    return ValueListenableBuilder<AudioTrackInfo?>(
      valueListenable: player.trackNotifier,
      builder: (context, track, _) {
        if (track == null) return const SizedBox.shrink();

        return ValueListenableBuilder<BackgroundAudioStatus>(
          valueListenable: player.statusNotifier,
          builder: (context, status, _) {
            if (status == BackgroundAudioStatus.idle) {
              return const SizedBox.shrink();
            }

            return ValueListenableBuilder<Duration>(
              valueListenable: player.positionNotifier,
              builder: (context, position, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: player.durationNotifier,
                  builder: (context, duration, _) {
                    return _MiniPlayerContent(
                      track: track,
                      status: status,
                      position: position,
                      duration: duration,
                      player: player,
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

class _MiniPlayerContent extends StatelessWidget {
  final AudioTrackInfo track;
  final BackgroundAudioStatus status;
  final Duration position;
  final Duration duration;
  final BackgroundAudioPlayerState player;

  const _MiniPlayerContent({
    required this.track,
    required this.status,
    required this.position,
    required this.duration,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isPlaying = status == BackgroundAudioStatus.playing;
    final isLoading = status == BackgroundAudioStatus.loading;

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const .symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _navigateToMessage(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
              child: Row(
                children: [
                  // Play / Pause — M3 FilledTonalIconButton
                  _buildPlayPauseButton(
                    colorScheme: colorScheme,
                    isPlaying: isPlaying,
                    isLoading: isLoading,
                  ),
                  const SizedBox(width: 12),
                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (track.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            track.subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Timestamp
                  Text(
                    _formatDuration(position),
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  // Close button — M3 standard IconButton
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: player.stop,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                    tooltip: 'Stop',
                  ),
                ],
              ),
            ),
          ),
          // Progress indicator — thin M3 linear indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: isLoading ? null : progress,
                minHeight: 3,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton({
    required ColorScheme colorScheme,
    required bool isPlaying,
    required bool isLoading,
  }) {
    if (isLoading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return IconButton.filledTonal(
      onPressed: player.togglePlayPause,
      icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        minimumSize: const Size(40, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltip: isPlaying ? 'Pause' : 'Play',
    );
  }

  void _navigateToMessage(BuildContext context) {
    final event = player.playingEvent;
    if (event == null) {
      Logs().w("playingEvent = null");
      return;
    }

    if (event.relationshipType == RelationshipTypes.thread &&
        event.relationshipEventId != null) {
      context.go(
        '/rooms/${event.roomId!}/threads/${event.relationshipEventId}?event=${event.eventId}',
      );
    } else {
      context.go('/rooms/${event.roomId!}?event=${event.eventId}');
    }
  }

  String _formatDuration(Duration d) {
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
