import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import '../../../config/app_config.dart';

class ReplyContent extends StatelessWidget {
  final Event replyEvent;
  final bool ownMessage;
  final Timeline? timeline;
  final Color? textColor;
  final bool noBubble;

  const ReplyContent(
    this.replyEvent, {
    this.textColor,
    this.noBubble = false,
    this.ownMessage = false,
    super.key,
    this.timeline,
  });

  static const BorderRadius borderRadius = BorderRadius.only(
    topRight: Radius.circular(AppConfig.borderRadius / 2),
    bottomRight: Radius.circular(AppConfig.borderRadius / 2),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final timeline = this.timeline;
    final displayEvent = timeline != null
        ? replyEvent.getDisplayEvent(timeline)
        : replyEvent;
    final fontSize =
        AppSettings.fontSizeFactor.value * AppSettings.messageFontSize.value;

    final color = theme.brightness == Brightness.dark
        ? (noBubble
              ? theme.colorScheme.onSurface
              : (ownMessage
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSecondaryContainer))
        : ownMessage
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.tertiary;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: fontSize * 2 + 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConfig.borderRadius),
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FutureBuilder<User?>(
                  initialData: displayEvent.senderFromMemoryOrFallback,
                  future: displayEvent.fetchSenderUser(),
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data?.calcDisplayname() ?? displayEvent.senderFromMemoryOrFallback.calcDisplayname()}:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor ?? color,
                        fontSize: fontSize,
                      ),
                    );
                  },
                ),
                Text(
                  displayEvent
                      .calcLocalizedBodyFallback(
                        MatrixLocals(L10n.of(context)),
                        withSenderNamePrefix: false,
                        hideReply: true,
                        plaintextBody: true,
                      )
                      .split('\n')
                      .first,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: textColor ?? color,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
