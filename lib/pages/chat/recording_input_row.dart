import 'package:flutter/material.dart';

import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat_input_row.dart';
import 'package:extera_next/pages/chat/recording_view_model.dart';

class RecordingInputRow extends StatelessWidget {
  final RecordingViewModelState state;
  final Future<void> Function(String, int, List<int>, String) onSend;
  final Future<void> Function(String, int, String)? onVideoSend;
  const RecordingInputRow({
    required this.state,
    required this.onSend,
    this.onVideoSend,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Video recording is now handled by VideoNoteRecordingDialog,
    // so this widget only handles audio recording.
    return _AudioRecordingInputRow(state: state, onSend: onSend);
  }
}

class _AudioRecordingInputRow extends StatelessWidget {
  final RecordingViewModelState state;
  final Future<void> Function(String, int, List<int>, String) onSend;

  const _AudioRecordingInputRow({required this.state, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const maxDecibalWidth = 36.0;
    final time =
        '${state.duration.inMinutes.toString().padLeft(2, '0')}:${(state.duration.inSeconds % 60).toString().padLeft(2, '0')}';
    return SizedBox(
      height: ChatInputRow.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 4),
          Container(
            alignment: Alignment.center,
            width: 48,
            child: IconButton(
              tooltip: L10n.of(context).cancel,
              icon: const Icon(Icons.delete_outlined),
              color: theme.colorScheme.error,
              onPressed: state.cancel,
            ),
          ),
          if (state.isPaused)
            Container(
              alignment: Alignment.center,
              width: 48,
              child: IconButton(
                tooltip: L10n.of(context).resume,
                icon: const Icon(Icons.play_circle_outline_outlined),
                onPressed: state.resume,
              ),
            )
          else
            Container(
              alignment: Alignment.center,
              width: 48,
              child: IconButton(
                tooltip: L10n.of(context).pause,
                icon: const Icon(Icons.pause_circle_outline_outlined),
                onPressed: state.pause,
              ),
            ),
          Text(time),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const width = 4;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: state.amplitudeTimeline.reversed
                      .take((constraints.maxWidth / (width + 2)).floor())
                      .toList()
                      .reversed
                      .map(
                        (amplitude) => Container(
                          margin: const EdgeInsets.only(left: 2),
                          width: width.toDouble(),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          height: maxDecibalWidth * (amplitude / 100),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          IconButton(
            style: IconButton.styleFrom(
              disabledBackgroundColor: theme.bubbleColor.withAlpha(128),
              backgroundColor: theme.bubbleColor,
              foregroundColor: theme.onBubbleColor,
            ),
            tooltip: L10n.of(context).sendAudio,
            icon: state.isSending
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator.adaptive(),
                  )
                : const Icon(Icons.send_outlined),
            onPressed: state.isSending ? null : () => state.stopAndSend(onSend),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
