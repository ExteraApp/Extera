import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:swipe_to_action/swipe_to_action.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/events/room_creation_state_event.dart';
import 'package:extera_next/utils/date_time_extension.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/poll_events.dart';
import 'package:extera_next/utils/string_color.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/member_actions_popup_menu_button.dart';
import '../../../config/app_config.dart';
import 'message_content.dart';
import 'message_reactions.dart';
import 'reply_content.dart';
import 'state_message.dart';

class Message extends StatefulWidget {
  final Event event;
  final Event? nextEvent;
  final Event? previousEvent;
  final bool displayReadMarker;
  final void Function(Event, Offset?) onSelect;
  final void Function(Event) onInfoTab;
  final void Function(String) scrollToEventId;
  final void Function() onSwipe;
  final void Function() onMention;
  final bool longPressSelect;
  final bool selected;
  final Timeline timeline;
  final bool highlightMarker;
  final bool animateIn;
  final bool wallpaperMode;
  final ScrollController? scrollController;
  final List<Color> colors;
  final bool gradient;
  final bool singleSelected;
  final Thread? thread;
  final bool hasBeenRead;

  const Message(
    this.event, {
    this.nextEvent,
    this.previousEvent,
    this.displayReadMarker = false,
    this.longPressSelect = false,
    this.gradient = false,
    this.singleSelected = false,
    this.hasBeenRead = false,
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
    required this.colors,
    super.key,
  });

  @override
  State<Message> createState() => _MessageState();
}

class _MessageState extends State<Message> {
  Offset _tapPosition = Offset.zero;

  // Cached futures to avoid re-creating them on every build
  late Future<User?> _senderUserFuture;
  Future<Event?>? _replyEventFuture;
  Future<User?>? _threadSenderFuture;

  @override
  void initState() {
    super.initState();
    _initFutures();
  }

  @override
  void didUpdateWidget(Message oldWidget) {
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
        final infoMap = event.content.tryGetMap<String, Object?>('info');
        final videoWidth = infoMap?.tryGet<int>('w') ?? 400;
        final videoHeight = infoMap?.tryGet<int>('h') ?? 300;
        const height = 300.0;
        return videoWidth * (height / videoHeight);

      default:
        return null;
    }
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
      return StateMessage(event);
    }

    if (event.type == EventTypes.Message &&
        event.messageType == EventTypes.KeyVerificationRequest) {
      return StateMessage(event);
    }

    final client = Matrix.of(context).client;
    final ownMessage = event.senderId == client.userID;
    final alignment = ownMessage ? Alignment.topRight : Alignment.topLeft;
    final hasBeenRead = widget.hasBeenRead;

    var color = theme.colorScheme.surfaceContainerHigh;
    final displayTime =
        event.type == EventTypes.RoomCreate ||
        widget.nextEvent == null ||
        !event.originServerTs.sameEnvironment(widget.nextEvent!.originServerTs);
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
        ({
              MessageTypes.Video,
              MessageTypes.Image,
              MessageTypes.Sticker,
            }.contains(event.messageType) &&
            event.fileDescription == null &&
            !event.redacted) ||
        (event.messageType == MessageTypes.Text &&
            event.relationshipType == null &&
            event.onlyEmotes &&
            event.numberEmotes > 0 &&
            event.numberEmotes <= 3);

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

    final messageStatusRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          event.originServerTs.localizedTimeOfDay(context),
          style: TextStyle(color: statusColor, fontSize: 11),
        ),
        if (event.hasAggregatedEvents(timeline, RelationshipTypes.edit))
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(Icons.edit_outlined, color: statusColor, size: 14),
          ),
        if (ownMessage)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(
              event.status == EventStatus.sending
                  ? Icons.watch_later_outlined
                  : event.status == EventStatus.error
                  ? Icons.error_outline
                  : hasBeenRead
                  ? Icons.done_all
                  : Icons.check,
              color: statusColor,
              size: 14,
            ),
          ),
      ],
    );

    final row = FutureBuilder<User?>(
      future: _senderUserFuture,
      builder: (context, snapshot) {
        final user = snapshot.data ?? event.senderFromMemoryOrFallback;
        final displayname =
            snapshot.data?.calcDisplayname() ??
            event.senderFromMemoryOrFallback.calcDisplayname();
        return Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: InkWell(
                onTapDown: (details) => _tapPosition = details.globalPosition,
                onTap: () => widget.onSelect(event, _tapPosition),
                onLongPress: () => widget.onSelect(event, _tapPosition),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: rowMainAxisAlignment,
              children: [
                if (widget.longPressSelect)
                  SizedBox(
                    height: 32,
                    width: Avatar.defaultSize,
                    child: Checkbox.adaptive(
                      value: widget.selected,
                      shape: const CircleBorder(),
                      onChanged: (_) => widget.onSelect(event, null),
                    ),
                  )
                else if (nextEventSameSender || ownMessage)
                  SizedBox(
                    width: Avatar.defaultSize,
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
                    onTap: () => showMemberActionsPopupMenu(
                      context: context,
                      user: user,
                      onMention: widget.onMention,
                    ),
                    presenceUserId: user.stateKey,
                    presenceBackgroundColor: widget.wallpaperMode
                        ? Colors.transparent
                        : null,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!nextEventSameSender)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                          child: ownMessage || event.room.isDirectChat
                              ? const SizedBox(height: 12)
                              : Text(
                                  displayname,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (theme.brightness == Brightness.light
                                        ? displayname.color
                                        : displayname.lightColorText),
                                    shadows: !widget.wallpaperMode
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
                                ),
                        ),
                      Container(
                        alignment: alignment,
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onLongPress: widget.longPressSelect
                              ? null
                              : () {
                                  HapticFeedback.heavyImpact();
                                  widget.onSelect(event, null);
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: noBubble ? Colors.transparent : color,
                              borderRadius: borderRadius,
                            ),
                            clipBehavior: Clip.antiAlias,
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
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_replyEventFuture != null)
                                              FutureBuilder<Event?>(
                                                future: _replyEventFuture,
                                                builder: (BuildContext context, snapshot) {
                                                  final replyEvent =
                                                      snapshot.hasData
                                                      ? snapshot.data!
                                                      : Event(
                                                          eventId:
                                                              event
                                                                  .inReplyToEventId() ??
                                                              '\$fake_event_id',
                                                          content: {
                                                            'msgtype': 'm.text',
                                                            'body': '...',
                                                          },
                                                          senderId:
                                                              event.senderId,
                                                          type:
                                                              'm.room.message',
                                                          room: event.room,
                                                          status:
                                                              EventStatus.sent,
                                                          originServerTs:
                                                              DateTime.now(),
                                                        );
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 16,
                                                          right: 16,
                                                          top: 8,
                                                          bottom: 8,
                                                        ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      borderRadius: ReplyContent
                                                          .borderRadius,
                                                      child: InkWell(
                                                        borderRadius:
                                                            ReplyContent
                                                                .borderRadius,
                                                        onTap: () => widget
                                                            .scrollToEventId(
                                                              replyEvent
                                                                  .eventId,
                                                            ),
                                                        child: AbsorbPointer(
                                                          child: ReplyContent(
                                                            replyEvent,
                                                            noBubble: noBubble,
                                                            ownMessage:
                                                                ownMessage,
                                                            timeline: timeline,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
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
                                                    ? 6
                                                    : 0,
                                              ),
                                              child: MessageContent(
                                                displayEvent,
                                                textColor: textColor,
                                                linkColor: linkColor,
                                                onInfoTab: widget.onInfoTab,
                                                borderRadius: borderRadius,
                                                timeline: timeline,
                                                selectable:
                                                    PlatformInfos.isMobile
                                                    ? widget.longPressSelect
                                                    : true,
                                              ),
                                            ),
                                            Opacity(
                                              opacity: 0,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 16,
                                                  bottom: 6,
                                                  left: 16,
                                                ),
                                                child: messageStatusRow,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          right: 16,
                                          child: messageStatusRow,
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
                          alignment: ownMessage
                              ? Alignment.bottomRight
                              : Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: InkWell(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
              padding: displayTime
                  ? const EdgeInsets.symmetric(vertical: 8.0)
                  : EdgeInsets.zero,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Material(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius * 2,
                    ),
                    color: theme.colorScheme.surface.withAlpha(128),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
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
                left: (ownMessage ? 0 : Avatar.defaultSize) + 12.0,
                right: ownMessage ? 0 : 12.0,
              ),
              child: MessageReactions(event, timeline),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 16.0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(child: Icon(Icons.check_outlined)),
          ),
          direction: AppSettings.swipeRightToLeftToReply.value
              ? SwipeDirection.endToStart
              : SwipeDirection.startToEnd,
          onSwipe: (_) => widget.onSwipe(),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: FluffyThemes.columnWidth * 2.5,
            ),
            padding: EdgeInsets.only(
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
        colors,
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
    if (!widget.animateIn) return widget.child;
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
