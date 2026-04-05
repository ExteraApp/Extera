import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart' show TimelineChunk;

import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/events/message.dart';
import 'package:extera_next/pages/chat_list/search_title.dart';
import 'package:extera_next/pages/notifications/notifications.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';
import 'package:extera_next/widgets/matrix.dart';

class NotificationsView extends StatelessWidget {
  final NotificationsController controller;
  const NotificationsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final theme = Theme.of(context);
    final colors = [theme.secondaryBubbleColor, theme.bubbleColor];

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).notifications)),
      body: MaxWidthBody(
        child: Column(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SegmentedButton<bool>(
                  showSelectedIcon:
                      false, // Cleaner look for text-only segments
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(L10n.of(context).all),
                      icon: const Icon(Icons.all_inbox),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(L10n.of(context).mentions),
                      icon: const Icon(Icons.alternate_email),
                    ),
                  ],
                  selected: {controller.showOnlyMentions},
                  onSelectionChanged: (Set<bool> newSelection) {
                    controller.setOnlyMentions(newSelection.first);
                  },
                ),
              ),
            ),
            controller.notifications == null ||
                    controller.notifications!.isEmpty
                ? const Center(child: CircularProgressIndicator.adaptive())
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.notifications!.length,
                    itemBuilder: (context, i) {
                      final notification = controller.notifications![i];
                      final showRoomName =
                          i == 0 ||
                          controller.notifications![i - 1].roomId !=
                              notification.roomId;
                      final room = client.getRoomById(notification.roomId);
                      final event = Event.fromMatrixEvent(
                        notification.event,
                        room!,
                      );

                      final message = Message(
                        event,
                        colors: colors,
                        onInfoTab: (Event ev) => {},
                        onMention: () => {},
                        onSelect: (Event ev, Offset? tapPosition) {
                          if (ev.relationshipType != RelationshipTypes.thread) {
                            context.push(
                              "/rooms/${room.id}?event=${ev.eventId}",
                            );
                          } else {
                            context.push(
                              "/rooms/${room.id}/threads/${ev.relationshipEventId}?event=${ev.eventId}",
                            );
                          }
                        },
                        onSwipe: () => {},
                        scrollToEventId: (String p0) => {},
                        timeline: RoomTimeline(
                          room: room,
                          chunk: TimelineChunk(events: [event]),
                        ),
                        animateIn: false,
                        displayReadMarker: false,
                        highlightMarker: false,
                        longPressSelect: false,
                        selected: false,
                        wallpaperMode: false,
                        gradient: false,
                      );

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showRoomName)
                            SearchTitle(
                              title: room.getLocalizedDisplayname(),
                              icon: const Icon(Icons.chat_bubble_outline),
                            ),
                          message,
                        ],
                      );
                    },
                  ),
            if (controller.notifications != null &&
                controller.notifications!.isNotEmpty)
              FilledButton(
                onPressed: controller.loadNotifications,
                child: controller.isLoadingNotifications
                    ? const LinearProgressIndicator()
                    : Text(L10n.of(context).loadMore),
              ),
          ],
        ),
      ),
    );
  }
}
