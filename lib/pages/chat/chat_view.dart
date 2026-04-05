import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:badges/badges.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/pages/chat/chat_app_bar_list_tile.dart';
import 'package:extera_next/pages/chat/chat_app_bar_title.dart';
import 'package:extera_next/pages/chat/chat_event_list.dart';
import 'package:extera_next/pages/chat/encryption_button.dart';
import 'package:extera_next/pages/chat/jitsi_popup_button.dart';
import 'package:extera_next/pages/chat/pinned_events.dart';
import 'package:extera_next/pages/chat/reply_display.dart';
import 'package:extera_next/pages/dialer/back_to_call_button.dart';
import 'package:extera_next/utils/account_config.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/chat_settings_popup_menu.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/mini_audio_player.dart';
import 'package:extera_next/widgets/mxc_image.dart';
import 'package:extera_next/widgets/unread_rooms_badge.dart';
import '../../utils/stream_extension.dart';
import 'chat_emoji_picker.dart';
import 'chat_input_row.dart';

enum _EventContextAction {
  info,
  recover,
  report,
  endPoll,
  copyLink,
  readReceipts,
}

class ChatView extends StatelessWidget {
  final ChatController controller;

  const ChatView(this.controller, {super.key});

  List<Widget> _appBarActions(BuildContext context) {
    if (controller.selectMode) {
      return [
        if (controller.canEditSelectedEvents)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: L10n.of(context).edit,
            onPressed: controller.editSelectedEventAction,
          ),
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: L10n.of(context).copy,
          onPressed: controller.copyEventsAction,
        ),
        if (controller.selectedEvents.length > 1)
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: L10n.of(context).copyLink,
            onPressed: controller.copyLinkAction,
          ),
        if (controller.canSaveSelectedEvent)
          // Use builder context to correctly position the share dialog on iPad
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.download),
              tooltip: L10n.of(context).downloadFile,
              onPressed: () => controller.saveSelectedEvent(context),
            ),
          ),
        if (controller.canPinSelectedEvents)
          IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            onPressed: controller.pinEvent,
            tooltip: L10n.of(context).pinMessage,
          ),
        if (controller.canRedactSelectedEvents)
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            tooltip: L10n.of(context).redactMessage,
            onPressed: controller.redactEventsAction,
          ),
        if (controller.selectedEvents.length == 1)
          PopupMenuButton<_EventContextAction>(
            onSelected: (action) {
              switch (action) {
                case _EventContextAction.info:
                  controller.showEventInfo();
                  controller.clearSelectedEvents();
                  break;
                case _EventContextAction.report:
                  controller.reportEventAction();
                  break;
                case _EventContextAction.recover:
                  controller.recoverEventAction();
                  break;
                case _EventContextAction.copyLink:
                  controller.copyLinkAction();
                  break;
                case _EventContextAction.endPoll:
                  controller.endPollAction();
                  break;
                case _EventContextAction.readReceipts:
                  controller.showReadReceipts();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _EventContextAction.info,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).messageInfo),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _EventContextAction.readReceipts,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.done_all),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).readReceipts),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _EventContextAction.copyLink,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).copyLink),
                  ],
                ),
              ),
            ],
          ),
      ];
    } else if (!controller.room.isArchived) {
      return [
        if (AppSettings.experimentalVoip.value &&
            Matrix.of(context).voipPlugin != null &&
            controller.room.isDirectChat)
          IconButton(
            onPressed: controller.onPhoneButtonTap,
            icon: const Icon(Icons.call_outlined),
            tooltip: L10n.of(context).placeCall,
          )
        else if (AppSettings.experimentalJitsi.value)
          JitsiPopupButton(controller.room),
        EncryptionButton(controller.room),
        ChatSettingsPopupMenu(controller.room, true),
      ];
    }
    return [];
  }

  Widget _buildInviteView(BuildContext context) {
    final theme = Theme.of(context);
    final room = controller.room;
    final membershipEvent = room.getState(
      EventTypes.RoomMember,
      room.client.userID!,
    );
    final topic = room.topic;
    final reason = membershipEvent?.content.tryGet<String>('reason');
    final displayName = room.getLocalizedDisplayname();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).newInvitation),
        automaticallyImplyLeading: false,
        leading: FluffyThemes.isColumnMode(context)
            ? null
            : const Center(child: BackButton()),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                // Room avatar
                Avatar(
                  mxContent: AppSettings.hideAvatarsInInvites.value
                      ? null
                      : room.avatar,
                  name: displayName,
                  size: 96,
                  client: room.client,
                ),
                const SizedBox(height: 24),
                // Room name
                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Invited by
                if (membershipEvent != null)
                  Text(
                    L10n.of(context).youInvitedBy(membershipEvent.senderId),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  )
                else if (room.directChatMatrixID != null)
                  Text(
                    L10n.of(context).newChatRequest,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    L10n.of(context).inviteGroupChat,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                // Reason
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.format_quote_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  L10n.of(context).reason,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(reason, style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Topic
                if (topic.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L10n.of(context).chatDescription,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableLinkify(
                            text: topic,
                            options: const LinkifyOptions(humanize: false),
                            linkStyle: TextStyle(
                              color: theme.colorScheme.primary,
                              decorationColor: theme.colorScheme.primary,
                            ),
                            style: theme.textTheme.bodyMedium,
                            onOpen: (url) =>
                                UrlLauncher(context, url.url).launchUrl(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => controller.acceptInvite(),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(L10n.of(context).accept),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => controller.declineInvite(),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(L10n.of(context).decline),
                    style: FilledButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      backgroundColor: theme.colorScheme.errorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => controller.ignoreInvite(),
                    icon: const Icon(Icons.block_outlined),
                    label: Text(L10n.of(context).block),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.room.membership == Membership.invite) {
      return _buildInviteView(context);
    }
    final bottomSheetPadding = FluffyThemes.isColumnMode(context) ? 16.0 : 8.0;
    final scrollUpBannerEventId = controller.scrollUpBannerEventId;

    final accountConfig = Matrix.of(context).client.applicationAccountConfig;

    return PopScope(
      canPop: controller.selectedEvents.isEmpty && !controller.showEmojiPicker,
      onPopInvokedWithResult: (pop, _) async {
        if (pop) return;
        if (controller.selectedEvents.isNotEmpty) {
          controller.clearSelectedEvents();
        } else if (controller.showEmojiPicker) {
          controller.emojiPickerAction();
        }
      },
      child: StreamBuilder(
        stream: controller.room.client.onRoomState.stream
            .where((update) => update.roomId == controller.room.id)
            .rateLimit(const Duration(seconds: 1)),
        builder: (context, snapshot) => FutureBuilder(
          future: controller.loadTimelineFuture,
          builder: (BuildContext context, snapshot) {
            var appbarBottomHeight = 0.0;
            if (controller.room.pinnedEventIds.isNotEmpty) {
              appbarBottomHeight += ChatAppBarListTile.fixedHeight;
            }
            return Scaffold(
              appBar: AppBar(
                actionsIconTheme: IconThemeData(
                  color: controller.selectedEvents.isEmpty
                      ? null
                      : theme.colorScheme.tertiary,
                ),
                automaticallyImplyLeading: false,
                leading: controller.selectMode
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: controller.clearSelectedEvents,
                        tooltip: L10n.of(context).close,
                        color: theme.colorScheme.tertiary,
                      )
                    : FluffyThemes.isColumnMode(context)
                    ? null
                    : StreamBuilder<Object>(
                        stream: Matrix.of(context).client.onSync.stream.where(
                          (syncUpdate) => syncUpdate.hasRoomUpdate,
                        ),
                        builder: (context, _) => UnreadRoomsBadge(
                          filter: (r) => r.id != controller.roomId,
                          badgePosition: BadgePosition.topEnd(end: 8, top: 4),
                          child: const Center(child: BackButton()),
                        ),
                      ),

                titleSpacing: FluffyThemes.isColumnMode(context) ? 24 : 0,
                title: ChatAppBarTitle(controller),
                actions: _appBarActions(context),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(appbarBottomHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [PinnedEvents(controller)],
                  ),
                ),
              ),
              floatingActionButton:
                  controller.showScrollDownButton &&
                      controller.selectedEvents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 56.0),
                      child: FloatingActionButton(
                        onPressed: controller.scrollDown,
                        heroTag: null,
                        mini: true,
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                        child: const Icon(Icons.arrow_downward_outlined),
                      ),
                    )
                  : null,
              body: DropTarget(
                onDragDone: controller.onDragDone,
                onDragEntered: controller.onDragEntered,
                onDragExited: controller.onDragExited,
                child: Stack(
                  children: <Widget>[
                    if (accountConfig.wallpaperUrl != null)
                      Opacity(
                        opacity: accountConfig.wallpaperOpacity ?? 0.5,
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: accountConfig.wallpaperBlur ?? 0.0,
                            sigmaY: accountConfig.wallpaperBlur ?? 0.0,
                          ),
                          child: MxcImage(
                            cacheKey: accountConfig.wallpaperUrl.toString(),
                            uri: accountConfig.wallpaperUrl,
                            fit: BoxFit.cover,
                            height: MediaQuery.sizeOf(context).height,
                            width: MediaQuery.sizeOf(context).width,
                            isThumbnail: false,
                            placeholder: (_) => Container(),
                          ),
                        ),
                      ),
                    SafeArea(
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: GestureDetector(
                              onTap: controller.clearSingleSelectedEvent,
                              child: ChatEventList(
                                controller: controller,
                                showThreadRoots: controller.showThreadRoots,
                              ),
                            ),
                          ),
                          if (controller.showScrollDownButton)
                            Divider(height: 1, color: theme.dividerColor),
                          if (controller.room.isExtinct)
                            Container(
                              margin: EdgeInsets.all(bottomSheetPadding),
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.chevron_right),
                                label: Text(L10n.of(context).enterNewChat),
                                onPressed: controller.goToNewRoomAction,
                              ),
                            )
                          else if (controller.room.canSendDefaultMessages &&
                              controller.room.membership == Membership.join &&
                              !controller.showThreadRoots)
                            Container(
                              margin: EdgeInsets.all(bottomSheetPadding),
                              constraints: const BoxConstraints(
                                maxWidth: FluffyThemes.columnWidth * 2.5,
                              ),
                              alignment: Alignment.center,
                              child: Material(
                                clipBehavior: Clip.hardEdge,
                                color: theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(24),
                                child: controller.room.isAbandonedDMRoom == true
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.all(16),
                                              foregroundColor:
                                                  theme.colorScheme.error,
                                            ),
                                            icon: const Icon(
                                              Icons.archive_outlined,
                                            ),
                                            onPressed: controller.leaveChat,
                                            label: Text(L10n.of(context).leave),
                                          ),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.all(16),
                                            ),
                                            icon: const Icon(
                                              Icons.forum_outlined,
                                            ),
                                            onPressed: controller.recreateChat,
                                            label: Text(
                                              L10n.of(context).reopenChat,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // ReactionsPicker(controller),
                                          ReplyDisplay(controller),
                                          ChatInputRow(controller),
                                          ChatEmojiPicker(controller),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (controller.dragging)
                      Container(
                        color: theme.scaffoldBackgroundColor.withAlpha(230),
                        alignment: Alignment.center,
                        child: const Icon(Icons.upload_outlined, size: 100),
                      ),

                    if (scrollUpBannerEventId != null)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          child: Align(
                            alignment: .center,
                            child: Row(
                              mainAxisSize: .min,
                              children: [
                                FilledButton(
                                  onPressed: () {
                                    controller.scrollToEventId(
                                      scrollUpBannerEventId,
                                    );
                                    controller.discardScrollUpBannerEventId();
                                    // controller.setReadMarker();
                                  },
                                  style: FilledButton.styleFrom(
                                    shadowColor: Colors.black,
                                    elevation: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.arrow_upward),
                                      const SizedBox(width: 18),
                                      Text(
                                        L10n.of(context).jumpToLastReadMessage,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: const BackToCallButton(),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: const MiniAudioPlayer(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
