import 'package:flutter/material.dart';

import 'package:scroll_to_index/scroll_to_index.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/pages/chat/events/message.dart';
import 'package:extera_next/pages/chat/typing_indicators.dart';
import 'package:extera_next/utils/account_config.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/filtered_timeline_extension.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/room_status_extension.dart';

class ChatEventList extends StatelessWidget {
  final ChatController controller;
  final bool showThreadRoots;

  const ChatEventList({
    super.key,
    required this.controller,
    this.showThreadRoots = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeline = controller.timeline;

    if (timeline == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final theme = Theme.of(context);

    final colors = [theme.secondaryBubbleColor, theme.bubbleColor];

    final latestReadEvent = controller.room.getLatestReadMessage(timeline);

    final horizontalPadding = FluffyThemes.isColumnMode(context) ? 8.0 : 0.0;

    var events = timeline.events;

    if (showThreadRoots) {
      events = events.filterThreadRoots();
    } else {
      events = events.filterByThreaded(controller.thread != null);
    }

    events = events.filterByVisibleInGui();

    final threads = controller.room.threads;

    final thisEventsKeyMap = <String, int>{};
    for (var i = 0; i < events.length; i++) {
      thisEventsKeyMap[events[i].eventId] = i;
    }

    final hasWallpaper =
        controller.room.client.applicationAccountConfig.wallpaperUrl != null;

    final latestReadEventIndex = latestReadEvent != null
        ? events.indexWhere((event) => event.eventId == latestReadEvent)
        : -1;

    return CustomScrollView(
      controller: controller.scrollController,
      reverse: true,
      keyboardDismissBehavior: PlatformInfos.isIOS
          ? ScrollViewKeyboardDismissBehavior.onDrag
          : ScrollViewKeyboardDismissBehavior.manual,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(
            top: 16,
            bottom: 8,
            left: horizontalPadding,
            right: horizontalPadding,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int i) {
                if (i == 0) {
                  if (timeline.canRequestFuture) {
                    return Center(
                      child: ElevatedButton(
                        onPressed: controller.requestFuture,
                        child: timeline.isRequestingFuture
                            ? const LinearProgressIndicator()
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_downward),
                                  const SizedBox(width: 5),
                                  Text(L10n.of(context).loadMore),
                                ],
                              ),
                      ),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [TypingIndicators(controller)],
                  );
                }

                if (i == events.length + 1) {
                  if (timeline.canRequestHistory) {
                    final visibleIndex = timeline.events.lastIndexWhere(
                      (event) => event.isVisibleInGui,
                    );
                    if (visibleIndex > timeline.events.length - 50) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        controller.requestHistory,
                      );
                    }
                    // Add top padding when scroll banner is visible to prevent overlap
                    final hasScrollBanner =
                        controller.scrollUpBannerEventId != null;
                    return Padding(
                      padding: EdgeInsets.only(
                        top: hasScrollBanner ? 72.0 : 0.0,
                      ),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: controller.requestHistory,
                          child: timeline.isRequestingHistory
                              ? const LinearProgressIndicator()
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_upward),
                                    const SizedBox(width: 5),
                                    Text(L10n.of(context).loadMore),
                                  ],
                                ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
                i--;

                final event = events[i];
                final animateIn =
                    i == 0 &&
                    (DateTime.now().millisecondsSinceEpoch -
                            event.originServerTs.millisecondsSinceEpoch) <
                        1000 &&
                    controller.firstUpdateReceived;

                final thread = threads.containsKey(event.eventId)
                    ? threads[event.eventId]
                    : null;

                return AutoScrollTag(
                  key: ValueKey(event.transactionId ?? event.eventId),
                  index: i,
                  controller: controller.scrollController,
                  child: RepaintBoundary(
                    child: Message(
                      event,
                      // key: ValueKey(event.eventId),
                      animateIn: animateIn,
                      thread: thread,
                      singleSelected:
                          controller.selectedEvents.length == 1 &&
                          controller.selectedEvents.first.eventId ==
                              event.eventId,
                      onSwipe: () => controller.replyAction(replyTo: event),
                      hasBeenRead:
                          latestReadEventIndex != -1 &&
                          latestReadEventIndex <= i,
                      // onQuote: () {
                      //   controller.replyAction(replyTo: event);
                      //   controller.sendController.text = "> ";
                      // },
                      onInfoTab: controller.showEventInfo,
                      onMention: () => controller.sendController.text +=
                          '${event.senderFromMemoryOrFallback.mention} ',
                      highlightMarker:
                          controller.scrollToEventIdMarker == event.eventId,
                      onSelect: controller.onSelectMessage,
                      scrollToEventId: (String eventId) =>
                          controller.scrollToEventId(eventId),
                      longPressSelect: controller.selectedEvents.isNotEmpty,
                      selected: controller.selectedEvents.any(
                        (e) => e.eventId == event.eventId,
                      ),
                      timeline: timeline,
                      displayReadMarker:
                          i > 0 &&
                          controller.readMarkerEventId == event.eventId,
                      nextEvent: i + 1 < events.length ? events[i + 1] : null,
                      previousEvent: i > 0 ? events[i - 1] : null,
                      wallpaperMode: hasWallpaper,
                      colors: colors,
                      gradient: AppSettings.enableGradient.value,
                    ),
                  ),
                );
              },
              childCount: events.length + 2,
              findChildIndexCallback: (key) =>
                  controller.findChildIndexCallback(key, thisEventsKeyMap),
            ),
          ),
        ),
      ],
    );
  }
}
