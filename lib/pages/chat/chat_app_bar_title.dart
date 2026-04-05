import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/utils/date_time_extension.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:extera_next/utils/sync_status_localization.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/overflow_marquee.dart';
import 'package:extera_next/widgets/presence_builder.dart';

class ChatAppBarTitle extends StatelessWidget {
  final ChatController controller;
  const ChatAppBarTitle(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final room = controller.room;
    if (controller.selectedEvents.isNotEmpty) {
      return Text(
        controller.selectedEvents.length.toString(),
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
      );
    }
    return InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () {
        if (controller.thread != null) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/rooms/${room.id}');
          }
          return;
        }
        if (!controller.isArchived) {
          if (FluffyThemes.isThreeColumnMode(context)) {
            controller.toggleDisplayChatDetailsColumn();
          } else {
            context.go('/rooms/${room.id}/details');
          }
        }
      },
      child: Row(
        children: [
          Hero(
            tag: 'content_banner',
            child: controller.thread == null
                ? Avatar(
                    mxContent: room.avatar,
                    name: room.getLocalizedDisplayname(
                      MatrixLocals(L10n.of(context)),
                    ),
                    size: 32,
                  )
                : Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.grey[200],
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.thread == null
                      ? room.getLocalizedDisplayname(
                          MatrixLocals(L10n.of(context)),
                        )
                      : '${controller.thread!.rootEvent.senderFromMemoryOrFallback.displayName ?? controller.thread!.rootEvent.senderId}: ${controller.thread!.rootEvent.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
                StreamBuilder(
                  stream: room.client.onSyncStatus.stream,
                  builder: (context, snapshot) {
                    final status =
                        room.client.onSyncStatus.value ??
                        const SyncStatusUpdate(SyncStatus.waitingForResponse);
                    final hide =
                        FluffyThemes.isColumnMode(context) ||
                        (room.client.onSync.value != null &&
                            status.status != SyncStatus.error &&
                            room.client.prevBatch != null);
                    return AnimatedSize(
                      duration: FluffyThemes.animationDuration,
                      child: hide
                          ? PresenceBuilder(
                              userId: room.directChatMatrixID,
                              builder: (context, presence) {
                                final lastActiveTimestamp =
                                    presence?.lastActiveTimestamp;
                                final style = Theme.of(
                                  context,
                                ).textTheme.bodySmall;
                                if (presence?.currentlyActive == true) {
                                  return OverflowMarquee(
                                    text:
                                        "${L10n.of(context).currentlyActive}${presence?.statusMsg != null ? " | ${presence?.statusMsg}" : ""}",
                                    style: style!,
                                    velocity: 20.0,
                                    height: (style.fontSize ?? 12) + 2,
                                  );
                                }
                                if (lastActiveTimestamp != null) {
                                  return OverflowMarquee(
                                    text:
                                        L10n.of(context).lastActiveAgo(
                                          lastActiveTimestamp
                                              .localizedTimeShort(context),
                                        ) +
                                        (presence?.statusMsg != null
                                            ? " | ${presence?.statusMsg}"
                                            : ""),
                                    style: style!,
                                    velocity: 20.0,
                                    height: (style.fontSize ?? 12) + 2,
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            )
                          : Row(
                              children: [
                                SizedBox.square(
                                  dimension: 10,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 1,
                                    value: status.progress,
                                    valueColor: status.error != null
                                        ? AlwaysStoppedAnimation<Color>(
                                            Theme.of(context).colorScheme.error,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    status.calcLocalizedString(context),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: status.error != null
                                          ? Theme.of(context).colorScheme.error
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
