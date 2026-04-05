import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/widgets/matrix.dart';

class BackToCallButton extends StatelessWidget {
  const BackToCallButton({super.key});

  @override
  Widget build(BuildContext context) {
    final voipPlugin = Matrix.of(context).voipPlugin;

    if (voipPlugin == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<CallSession?>(
      valueListenable: voipPlugin.currentCallNotifier,
      builder: (context, currentCall, _) {
        if (currentCall == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: FilledButton.tonal(
            onPressed: () {
              voipPlugin.overlayMinimised = false;
              voipPlugin.overlayEntry?.markNeedsBuild();
            },
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.call),
                const SizedBox(width: 18),
                Text(L10n.of(context).backToCall),
              ],
            ),
          ),
        );
      },
    );
  }
}
