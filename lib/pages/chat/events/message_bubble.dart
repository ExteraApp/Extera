import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:swipe_to_action/swipe_to_action.dart';

import 'package:extera_next/config/app_settings.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/pages/chat/events/file_sending_indicator.dart';
import 'package:extera_next/pages/chat/events/room_creation_state_event.dart';
import 'package:extera_next/utils/date_time_extension.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/poll_events.dart';
import 'package:extera_next/utils/privacy_options.dart';
import 'package:extera_next/utils/string_color.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/member_actions_popup_menu_button.dart';
import '../../../config/app_config.dart';
import 'message_content.dart';
import 'message_reactions.dart';
import 'reply_content.dart';
import 'state_message.dart';

class MessageBubble extends StatefulWidget {
  final Event event;
  final Event? nextEvent;
  final Event? previousEvent;
  final bool displayReadMarker;
  final void Function(Event, Offset?) onSelect;
  final void Function(Event) onInfoTab;
  final void Function(String, String?) scrollToEventId;
  final void Function(Event) onSwipe;
  final void Function() onMention;
  final bool longPressSelect;
  final bool selected;
  final Timeline timeline;
  final bool highlightMarker;
  final bool animateIn;
  final bool wallpaperMode;
  final ScrollController? scrollController;
  final ChatController? chatController;
  final List<Color> colors;
  final bool gradient;
  final bool singleSelected;
  final Thread? thread;
  final bool hasBeenRead;
  final bool? exampleMessage;

  const MessageBubble(
    this.event, {
    this.nextEvent,
    this.previousEvent,
    this.displayReadMarker = false,
    this.longPressSelect = false,
    this.gradient = false,
    this.singleSelected = false,
    this.hasBeenRead = false,
    this.exampleMessage = false,
    this.thread,
    required this.onSelect,
    required this.onInfoTab,
    required this.scrollToEventId,
    required this.onSwipe,
    this.selected = false,
    required this.timeline,
    this.highlightMarker = false,
    this.animateIn = false,
    this.wallpaperMode = false,
    required this.onMention,
    this.scrollController,
    this.chatController,
    required this.colors,
    super.key,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Offset _tapPosition = Offset.zero;

  // Cached futures to avoid re-creating them on every build
  late Future<User?> _senderUserFuture;
  Future<Event?>? _replyEventFuture;
  Future<User?>? _threadSenderFuture;

  bool loadMedia = false;

  @override
  void initState() {
    super.initState();
    loadMedia = shouldAutoLoadMedia(
      widget.event.room.client,
      widget.event.room.id,
    );
    _initFutures();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event) {
      _initFutures();
    } else {
      // Only re-init thread future if thread changed
      if (oldWidget.thread?.lastEvent?.eventId !=
          widget.thread?.lastEvent?.eventId) {
        _initThreadFuture();
      }
    }
  }

  void _initFutures() {
    _senderUserFuture = fetchSenderUser();
    _initReplyFuture();
    _initThreadFuture();
  }

  Future<User?> fetchSenderUser() async {
    final client = Matrix.of(context).client;
    if (widget.event.senderId != client.userID) {
      return await widget.event.fetchSenderUser();
    }
    // we don't render avatar/displayname for own messages
    return User(client.userID!, room: widget.event.room);
  }

  void _initReplyFuture() {
    if (widget.event.inReplyToEventId(includingFallback: false) != null) {
      _replyEventFuture = widget.event.getReplyEvent(widget.timeline);
    } else {
      _replyEventFuture = null;
    }
  }

  void _initThreadFuture() {
    final threadLastEvent = widget.thread?.lastEvent;
    if (threadLastEvent != null &&
        threadLastEvent.relationshipEventId == widget.event.eventId) {
      _threadSenderFuture = threadLastEvent.fetchSenderUser();
    } else {
      _threadSenderFuture = null;
    }
  }

  /// Calculates the width of the media content (image/video/sticker) for
  /// the given event, matching the logic in [MessageContent], [ImageBubble],
  /// and [EventVideoPlayer]. Returns null if the event is not a media type.
  double? _calculateMediaWidth(Event event) {
    if (event.redacted) return null;

    switch (event.messageType) {
      case MessageTypes.Image:
      case MessageTypes.Sticker:
        final maxSize = event.messageType == MessageTypes.Sticker
            ? 128.0 * AppSettings.stickerScale.value
            : 512.0;
        final w = event.content
            .tryGetMap<String, Object?>('info')
            ?.tryGet<int>('w');
        final h = event.content
            .tryGetMap<String, Object?>('info')
            ?.tryGet<int>('h');
        var imageWidth = maxSize;
        if (w != null && h != null) {
          if (w > h) {
            imageWidth = maxSize;
          } else {
            imageWidth = max(32, maxSize * (w / h));
          }
        }
        final hasDescription = event.fileDescription != null;
        const minBubbleWidth = 180.0;
        return hasDescription ? max(minBubbleWidth, imageWidth) : imageWidth;

      case MessageTypes.Video:
        final maxSize = 384.0;

        final infoMap = event.content.tryGetMap<String, Object?>('info');
        final w = infoMap?.tryGet<int>('w');
        final h = infoMap?.tryGet<int>('h');
        final hasDescription = event.fileDescription != null;
        const minBubbleWidth = 180.0;
        // const height = 300.0;
        var width = maxSize;
        if (w != null && h != null) {
          if (w > h) {
            width = maxSize;
          } else {
            width = max(32, maxSize * (w / h));
          }
        }

        final bubbleWidth = hasDescription ? max(minBubbleWidth, width) : width;

        return bubbleWidth;

      default:
        return null;
    }
  }

  void _scrollToEvent(Event event, Event? scrolledFrom) {
    if (event.status == .error) return; // didn't load yet
    widget.scrollToEventId(event.eventId, scrolledFrom?.eventId);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final timeline = widget.timeline;
    final theme = Theme.of(context);

    if (!{
      EventTypes.Message,
      EventTypes.Sticker,
      EventTypes.Encrypted,
      EventTypes.CallInvite,
      PollEvents.PollStart,
    }.contains(event.type)) {
      if (event.type.startsWith('m.call.')) {
        return const SizedBox.shrink();
      }
      if (event.type == EventTypes.RoomCreate) {
        return RoomCreationStateEvent(event: event);
      }
      return StateMessage(
        event,
        selected: widget.selected,
        controller: widget.chatController,
      );
    }

    if (event.type == EventTypes.Message &&
        event.messageType == EventTypes.KeyVerificationRequest) {
      return StateMessage(
        event,
        selected: widget.selected,
        controller: widget.chatController,
      );
    }

    final client = Matrix.of(context).client;
    final ownMessage = event.senderId == client.userID;
    final alignment = ownMessage ? Alignment.topRight : Alignment.topLeft;
    final hasBeenRead = widget.hasBeenRead;

    var color = theme.colorScheme.surfaceContainerHigh;
    final displayTime =
        (event.type == EventTypes.RoomCreate ||
            widget.nextEvent == null ||
            !event.originServerTs.sameEnvironment(
              widget.nextEvent!.originServerTs,
            )) &&
        widget.exampleMessage != true;
    final nextEventSameSender =
        widget.nextEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
          EventTypes.Encrypted,
          PollEvents.PollStart,
        }.contains(widget.nextEvent!.type) &&
        widget.nextEvent!.senderId == event.senderId &&
        !displayTime;

    final previousEventSameSender =
        widget.previousEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
          EventTypes.Encrypted,
          PollEvents.PollStart,
        }.contains(widget.previousEvent!.type) &&
        widget.previousEvent!.senderId == event.senderId &&
        widget.previousEvent!.originServerTs.sameEnvironment(
          event.originServerTs,
        );

    final rowMainAxisAlignment = ownMessage
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;

    final displayEvent = event.getDisplayEvent(timeline);
    const hardCorner = Radius.circular(4);
    const roundedCorner = Radius.circular(AppConfig.borderRadius);
    final borderRadius = BorderRadius.only(
      topLeft: !ownMessage && nextEventSameSender ? hardCorner : roundedCorner,
      topRight: ownMessage && nextEventSameSender ? hardCorner : roundedCorner,
      bottomLeft: !ownMessage && previousEventSameSender
          ? hardCorner
          : roundedCorner,
      bottomRight: ownMessage && previousEventSameSender
          ? hardCorner
          : roundedCorner,
    );
    final noBubble =
        (event.messageType == MessageTypes.Sticker && !event.redacted) ||
        (event.messageType == MessageTypes.Text &&
            event.relationshipType == null &&
            event.onlyEmotes &&
            event.numberEmotes > 0 &&
            event.numberEmotes <= 3);

    final onlyMedia =
        {MessageTypes.Image, MessageTypes.Video}.contains(event.messageType) &&
        event.fileDescription == null &&
        !event.redacted;

    if (ownMessage) {
      color = displayEvent.status.isError
          ? Colors.redAccent
          : theme.bubbleColor;
    }

    final textColor = ownMessage
        ? (noBubble ? theme.colorScheme.onSurface : theme.onBubbleColor)
        : theme.colorScheme.onSurface;

    final statusColor = theme.brightness == Brightness.dark
        ? (noBubble
              ? theme.colorScheme.onSurface
              : (ownMessage
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSecondaryContainer))
        : ownMessage
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.tertiary;

    final linkColor = ownMessage
        ? theme.brightness == Brightness.light
              ? theme.colorScheme.primaryFixed
              : theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.primary;

    final showReactionsRow = event.hasAggregatedEvents(
      timeline,
      RelationshipTypes.reaction,
    );

    Widget buildStatusRow({required Color color}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          event.originServerTs.localizedMessageTime(context),
          style: TextStyle(color: color, fontSize: 11, height: 1.0),
        ),
        if (event.hasAggregatedEvents(timeline, RelationshipTypes.edit))
          Padding(
            padding: const EdgeInsets.only(left: 3.0),
            child: Icon(Icons.edit_outlined, color: color, size: 12),
          ),
        if (ownMessage)
          Padding(
            padding: const EdgeInsets.only(left: 3.0),
            child: event.fileSendingStatus != null
                ? FileSendingStatusIndicator(
                    event.fileSendingStatus!,
                    color: color,
                    size: 13,
                  )
                : Icon(
                    event.status == .sending
                        ? Icons.watch_later_outlined
                        : event.status == EventStatus.error
                        ? Icons.error_outline
                        : hasBeenRead
                        ? Icons.done_all
                        : Icons.check,
                    color: color,
                    size: 13,
                  ),
          ),
      ],
    );

    final messageStatusRow = buildStatusRow(color: statusColor);

    // A "chip" version with translucent backdrop, used over media/HTML where
    // we cannot inline the placeholder into the text flow.
    final messageStatusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: buildStatusRow(color: Colors.white),
    );

    // Decide where to place the status row.
    //
    // - inline (Telegram-style): for plain-text messages we append an invisible
    //   trailing placeholder to the last text line and overlay the visible
    //   status row exactly over that reserved space.
    // - chip overlay: over noBubble media (image/sticker without description,
    //   big emotes) we float a translucent pill on top of the content.
    // - bottom row: for HTML, captions, redacted, audio/file/poll we render
    //   the status as a real bottom-right row below the content. No overlap.
    final isTextLike =
        {
          MessageTypes.Text,
          MessageTypes.Notice,
          MessageTypes.Emote,
          MessageTypes.None,
        }.contains(event.messageType) ||
        event.redacted;
    final isBigEmote =
        noBubble &&
        event.messageType == MessageTypes.Text &&
        event.relationshipType == null &&
        event.onlyEmotes;

    final useInlineStatus =
        !noBubble &&
        !onlyMedia &&
        (isTextLike || event.fileDescription != null) &&
        !event.redacted;

    final useChipStatus = (noBubble || onlyMedia) && !isBigEmote;
    final useBottomChipStatus = isBigEmote;
    final useBottomRowStatus =
        !useInlineStatus && !useChipStatus && !useBottomChipStatus;

    final hasReplyRelation = event.inReplyToEventId(includingFallback: false) != null;

    final showSenderAtTop =
        !nextEventSameSender &&
        !ownMessage &&
        !event.room.isDirectChat &&
        (isTextLike ||
            hasReplyRelation ||
            event.messageType == MessageTypes.Audio ||
            event.messageType == MessageTypes.File) &&
        (event.messageType != MessageTypes.Sticker || event.redacted);

    final showSenderOverlay =
        !nextEventSameSender &&
        !ownMessage &&
        !event.room.isDirectChat &&
        (({
                  MessageTypes.Image,
                  MessageTypes.Video,
                  MessageTypes.Location,
                }.contains(event.messageType) &&
                !hasReplyRelation) ||
            event.messageType == MessageTypes.Sticker) &&
        !event.redacted;

    final replyDisplay = _replyEventFuture != null
        ? FutureBuilder<Event?>(
            future: _replyEventFuture,
            builder: (BuildContext context, snapshot) {
              final replyEvent = snapshot.hasData
                  ? snapshot.data!
                  : Event(
                      eventId: event.inReplyToEventId() ?? '\$fake_event_id',
                      content: {'msgtype': 'm.text', 'body': '...'},
                      senderId: event.senderId,
                      type: 'm.room.message',
                      room: event.room,
                      status: EventStatus.error,
                      originServerTs: DateTime.now(),
                    );
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: showSenderAtTop ? 4 : 8,
                  bottom:
                      noBubble ||
                          (event.messageType != MessageTypes.Text &&
                              event.messageType != MessageTypes.Notice)
                      ? 8
                      : 0,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    AppConfig.borderRadius - 10,
                  ),
                  onTap: () => _scrollToEvent(replyEvent, event),
                  child: AbsorbPointer(
                    child: ReplyContent(
                      replyEvent,
                      noBubble: noBubble,
                      ownMessage: ownMessage,
                      timeline: timeline,
                    ),
                  ),
                ),
              );
            },
          )
        : const SizedBox.shrink();

    final inlineStatusPlaceholder = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 2),
        child: Opacity(
          opacity: 0,
          child: IgnorePointer(child: messageStatusRow),
        ),
      ),
    );

    final row = FutureBuilder<User?>(
      future: _senderUserFuture,
      builder: (context, snapshot) {
        final user = snapshot.data ?? event.senderFromMemoryOrFallback;
        final displayname =
            snapshot.data?.calcDisplayname() ??
            event.senderFromMemoryOrFallback.calcDisplayname();

        final senderNameWidget = Text(
          displayname,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: (theme.brightness == Brightness.light
                ? displayname.color
                : displayname.lightColorText),
            shadows: !widget.wallpaperMode && !showSenderOverlay
                ? null
                : [
                    const Shadow(
                      offset: Offset(0.0, 0.0),
                      blurRadius: 3,
                      color: Colors.black,
                    ),
                  ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

        return Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: InkWell(
                onTapDown: (details) => _tapPosition = details.globalPosition,
                onSecondaryTapDown: (details) =>
                    _tapPosition = details.globalPosition,
                onTap: () => widget.onSelect(event, _tapPosition),
                onLongPress: () {
                  if (PlatformInfos.isMobile) {
                    widget.onSelect(event, _tapPosition);
                  }
                },
                onSecondaryTap: () => widget.onSelect(event, _tapPosition),
                borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
                child: Material(
                  borderRadius: BorderRadius.circular(
                    AppConfig.borderRadius / 2,
                  ),
                  color: widget.selected || widget.highlightMarker
                      ? theme.colorScheme.secondaryContainer.withAlpha(128)
                      : Colors.transparent,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: .start,
              mainAxisAlignment: rowMainAxisAlignment,
              children: [
                if (widget.longPressSelect)
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: Checkbox.adaptive(
                      value: widget.selected,
                      shape: const CircleBorder(),
                      onChanged: (_) => widget.onSelect(event, null),
                    ),
                  )
                else if (nextEventSameSender || ownMessage)
                  SizedBox(
                    width: 36,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: event.status == EventStatus.error
                            ? const Icon(Icons.error, color: Colors.red)
                            : event.fileSendingStatus != null
                            ? const CircularProgressIndicator.adaptive(
                                strokeWidth: 1,
                              )
                            : null,
                      ),
                    ),
                  )
                else
                  Avatar(
                    mxContent: user.avatarUrl,
                    name: user.calcDisplayname(),
                    size: 36,
                    onTap: () {
                      if (widget.exampleMessage != true) {
                        showMemberActionsPopupMenu(
                          context: context,
                          user: user,
                          onMention: widget.onMention,
                        );
                      }
                    },
                    presenceUserId: user.stateKey,
                    presenceBackgroundColor: widget.wallpaperMode
                        ? Colors.transparent
                        : null,
                  ),
                if (ownMessage &&
                    !event.redacted &&
                    event.type == EventTypes.Sticker)
                  Flexible(child: replyDisplay),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Container(
                        alignment: alignment,
                        padding: const EdgeInsets.only(left: 6),
                        child: GestureDetector(
                          onTapDown: (details) =>
                              _tapPosition = details.globalPosition,
                          onLongPress: widget.longPressSelect
                              ? null
                              : () {
                                  HapticFeedback.heavyImpact();
                                  widget.onSelect(event, _tapPosition);
                                },
                          child: Material(
                            color: noBubble
                                ? Colors.transparent
                                : AppSettings.enableChatFrostedGlass.value &&
                                      AppSettings.wallpaperPath.value.isNotEmpty
                                ? color.withValues(alpha: 0.7)
                                : color,
                            borderRadius: borderRadius,
                            clipBehavior: Clip.hardEdge,
                            child: BubbleBackground(
                              colors: widget.colors,
                              ignore:
                                  noBubble ||
                                  !ownMessage ||
                                  !widget.gradient ||
                                  MediaQuery.highContrastOf(context),
                              scrollController: widget.scrollController,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppConfig.borderRadius,
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      (_replyEventFuture != null
                                          ? _calculateMediaWidth(displayEvent)
                                          : null) ??
                                      FluffyThemes.columnWidth * 1.5,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Stack(
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              ownMessage && noBubble
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            if (showSenderAtTop)
                                              Padding(
                                                padding: const .only(
                                                  left: 16,
                                                  right: 16,
                                                  top: 8,
                                                  // bottom: 4,
                                                ),
                                                child: senderNameWidget,
                                              ),
                                            if (event.type !=
                                                EventTypes.Sticker)
                                              replyDisplay,
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top:
                                                    {
                                                      MessageTypes.Text,
                                                      MessageTypes.Emote,
                                                      MessageTypes.Notice,
                                                    }.contains(
                                                      event.messageType,
                                                    )
                                                    ? showSenderAtTop
                                                          ? 2
                                                          : 8
                                                    : showSenderAtTop
                                                    ? 2
                                                    : 0,
                                                bottom: useInlineStatus ? 8 : 0,
                                              ),
                                              child: MessageContent(
                                                displayEvent,
                                                textColor: textColor,
                                                linkColor: linkColor,
                                                onInfoTab: widget.onInfoTab,
                                                borderRadius: borderRadius,
                                                timeline: timeline,
                                                loadMedia: loadMedia,
                                                onLoadMedia: () {
                                                  setState(() {
                                                    loadMedia = true;
                                                  });
                                                },
                                                nextEventSameSender:
                                                    nextEventSameSender,
                                                previousEventSameSender:
                                                    previousEventSameSender,
                                                ownMessage: ownMessage,
                                                useBubbleLayout: true,
                                                selectable:
                                                    PlatformInfos.isMobile
                                                    ? widget.longPressSelect
                                                    : true,
                                                trailingSpan: useInlineStatus
                                                    ? inlineStatusPlaceholder
                                                    : null,
                                              ),
                                            ),
                                            // reserve vertical space for bottomrowstatus
                                            if (useBottomRowStatus)
                                              const SizedBox(height: 22),
                                            if (useBottomChipStatus)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                  left: 4,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [messageStatusChip],
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (showSenderOverlay)
                                          Positioned(
                                            left: 10,
                                            top: 10,
                                            child: Container(
                                              padding: const .symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.65,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: senderNameWidget,
                                            ),
                                          ),
                                        if (useInlineStatus)
                                          Positioned(
                                            bottom: 10,
                                            right: 16,
                                            child: messageStatusRow,
                                          ),
                                        if (useBottomRowStatus)
                                          Positioned(
                                            bottom: 6,
                                            right: 12,
                                            child: messageStatusRow,
                                          ),
                                        if (useChipStatus)
                                          Positioned(
                                            bottom: 6,
                                            right: 6,
                                            child: messageStatusChip,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.thread != null)
                        Align(
                          alignment: ownMessage ? .bottomRight : .bottomLeft,
                          child: Padding(
                            padding: const .only(
                              bottom: 8,
                              left: 24,
                              right: 8,
                              top: 8,
                            ),
                            child: InkWell(
                              child: Row(
                                mainAxisSize: .min,
                                children: [
                                  Icon(
                                    (widget.thread?.hasNewMessages ?? false)
                                        ? Icons.mark_chat_unread_outlined
                                        : Icons.chat_bubble_outline,
                                    color: Colors.grey[200],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 16),
                                  if (_threadSenderFuture != null)
                                    FutureBuilder<User?>(
                                      future: _threadSenderFuture,
                                      builder: (context, snapshot) {
                                        final threadUser =
                                            snapshot.data ??
                                            event.senderFromMemoryOrFallback;
                                        return Avatar(
                                          mxContent: threadUser.avatarUrl,
                                          name: threadUser.calcDisplayname(),
                                          size: 24,
                                        );
                                      },
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  const SizedBox(width: 6),
                                  widget.thread!.lastEvent != null
                                      ? Text(
                                          widget
                                                      .thread!
                                                      .lastEvent!
                                                      .text
                                                      .length >
                                                  32
                                              ? "${widget.thread!.lastEvent!.text.substring(0, 32)}..."
                                              : widget.thread!.lastEvent!.text,
                                        )
                                      : const Text('Thread'),
                                ],
                              ),
                              onTap: () => context.push(
                                '/rooms/${event.roomId}/threads/${event.eventId}',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!ownMessage &&
                    !event.redacted &&
                    event.type == EventTypes.Sticker)
                  Flexible(child: replyDisplay),
              ],
            ),
          ],
        );
      },
    );

    Widget container;
    if (showReactionsRow ||
        displayTime ||
        widget.selected ||
        widget.displayReadMarker) {
      container = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: ownMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          if (displayTime || widget.selected)
            Padding(
              padding: displayTime ? const .symmetric(vertical: 8.0) : .zero,
              child: Center(
                child: Padding(
                  padding: const .only(top: 4.0),
                  child: Material(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius * 2,
                    ),
                    color: theme.colorScheme.surface.withAlpha(128),
                    child: Padding(
                      padding: const .symmetric(horizontal: 8.0, vertical: 2.0),
                      child: Text(
                        event.originServerTs.localizedTime(context),
                        style: TextStyle(
                          fontSize: 12 * AppSettings.fontSizeFactor.value,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          row,
          if (showReactionsRow)
            Padding(
              padding: EdgeInsets.only(
                top: 4.0,
                left: (ownMessage ? 0 : 30) + 12.0,
                right: ownMessage ? 0 : 12.0,
              ),
              child: MessageReactions(
                event,
                timeline,
                chatController: widget.chatController,
              ),
            ),
          if (widget.displayReadMarker)
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                Container(
                  margin: const .symmetric(horizontal: 4, vertical: 16.0),
                  padding: const .symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 3,
                    ),
                    color: theme.colorScheme.surface.withAlpha(128),
                  ),
                  child: Text(
                    L10n.of(context).newMessages,
                    style: TextStyle(
                      fontSize: 12 * AppSettings.fontSizeFactor.value,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
        ],
      );
    } else {
      container = row;
    }

    return _AnimateIn(
      animateIn: widget.animateIn,
      halfOpacity: event.status == .sending ? true : false,
      child: Center(
        child: Swipeable(
          key: ValueKey(event.eventId),
          background: const Padding(
            padding: .symmetric(horizontal: 12.0),
            child: Center(child: Icon(Icons.check_outlined)),
          ),
          direction: AppSettings.swipeRightToLeftToReply.value
              ? SwipeDirection.endToStart
              : SwipeDirection.startToEnd,
          onSwipe: (_) => widget.onSwipe(event),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: FluffyThemes.columnWidth * 2.5,
            ),
            padding: .only(
              left: 8.0,
              right: 8.0,
              top: nextEventSameSender ? 1.0 : 4.0,
              bottom: previousEventSameSender ? 1.0 : 4.0,
            ),
            child: container,
          ),
        ),
      ),
    );
  }
}

class BubbleBackground extends StatelessWidget {
  const BubbleBackground({
    super.key,
    required this.colors,
    required this.ignore,
    required this.child,
    this.scrollController,
  });

  final ScrollController? scrollController;
  final List<Color> colors;
  final bool ignore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ignore) return child;
    return RepaintBoundary(
      child: CustomPaint(
        painter: BubblePainter(
          repaint: scrollController,
          colors: colors,
          context: context,
        ),
        child: child,
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  BubblePainter({
    required this.context,
    required this.colors,
    required super.repaint,
  });

  final BuildContext context;
  final List<Color> colors;
  ScrollableState? _scrollable;

  @override
  void paint(Canvas canvas, Size size) {
    final scrollable = _scrollable ??= Scrollable.of(context);
    final scrollableBox = scrollable.context.findRenderObject() as RenderBox;
    final scrollableRect = Offset.zero & scrollableBox.size;
    final bubbleBox = context.findRenderObject() as RenderBox;

    final origin = bubbleBox.localToGlobal(
      Offset.zero,
      ancestor: scrollableBox,
    );
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        scrollableRect.topCenter,
        scrollableRect.bottomCenter,
        AppSettings.enableChatFrostedGlass.value
            ? colors.map((x) => x.withValues(alpha: 0.7)).toList()
            : colors,
        [0.0, 1.0],
        TileMode.clamp,
        Matrix4.translationValues(-origin.dx, -origin.dy, 0.0).storage,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(BubblePainter oldDelegate) {
    final scrollable = Scrollable.of(context);
    final oldScrollable = _scrollable;
    _scrollable = scrollable;
    return scrollable.position != oldScrollable?.position;
  }
}

class _AnimateIn extends StatefulWidget {
  final bool animateIn;
  final bool halfOpacity;
  final Widget child;
  const _AnimateIn({
    required this.animateIn,
    required this.halfOpacity,
    required this.child,
  });

  @override
  State<_AnimateIn> createState() => __AnimateInState();
}

class __AnimateInState extends State<_AnimateIn> {
  bool _animationFinished = false;
  @override
  Widget build(BuildContext context) {
    if (!widget.animateIn) {
      return widget.halfOpacity
          ? Opacity(opacity: 0.5, child: widget.child)
          : widget.child;
    }
    if (!_animationFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _animationFinished = true;
        });
      });
    }
    return AnimatedOpacity(
      duration: FluffyThemes.animationDuration,
      curve: FluffyThemes.animationCurve,
      opacity: _animationFinished ? (widget.halfOpacity ? 0.5 : 1) : 0,
      child: AnimatedSize(
        duration: FluffyThemes.animationDuration,
        curve: FluffyThemes.animationCurve,
        child: _animationFinished ? widget.child : const SizedBox.shrink(),
      ),
    );
  }
}
