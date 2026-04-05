import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/generated/l10n/l10n.dart';

class EventRedactedContent extends StatelessWidget {
  final Event event;
  final Color textColor;
  final double fontSize;

  const EventRedactedContent({
    super.key,
    required this.event,
    required this.textColor,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: event.redactedBecause?.fetchSenderUser(),
      builder: (context, snapshot) {
        final reason = event.redactedBecause?.content.tryGet<String>('reason');
        final redactedBy =
            snapshot.data?.calcDisplayname() ??
            event.redactedBecause?.senderId.localpart ??
            L10n.of(context).user;

        final label = reason == null
            ? L10n.of(context).redactedBy(redactedBy)
            : L10n.of(context).redactedByBecause(redactedBy, reason);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '🗑️  $label',
            style: TextStyle(
              color: textColor.withAlpha(128),
              fontSize: fontSize,
            ),
          ),
        );
      },
    );
  }
}
