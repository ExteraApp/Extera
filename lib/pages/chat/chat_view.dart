import 'dart:io';
import 'dart:ui' as ui;

import 'package:extera_next/pages/chat/chat_floating_app_bar.dart';
import 'package:extera_next/pages/chat/chat_legacy_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/pages/chat/chat_app_bar_list_tile.dart';
import 'package:extera_next/pages/chat/chat_event_list.dart';
import 'package:extera_next/pages/chat/encryption_button.dart';
import 'package:extera_next/pages/chat/jitsi_popup_button.dart';
import 'package:extera_next/pages/chat/reply_display.dart';
import 'package:extera_next/pages/dialer/back_to_call_button.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/chat_settings_popup_menu.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/mini_audio_player.dart';
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

class ChatView extends StatefulWidget {
  final ChatController controller;

  const ChatView(this.controller, {super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  // A shorthand so we don’t have to write `widget.controller` everywhere.
  ChatController get controller => widget.controller;

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
                  children: const [
                    Icon(Icons.info_outlined),
                    SizedBox(width: 12),
                    // Text will be localized at runtime
                    // (cannot be const)
                  ],
                ),
              ),
              PopupMenuItem(
                value: _EventContextAction.readReceipts,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [Icon(Icons.done_all), SizedBox(width: 12)],
                ),
              ),
              PopupMenuItem(
                value: _EventContextAction.copyLink,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [Icon(Icons.link), SizedBox(width: 12)],
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
                Avatar(
                  mxContent: AppSettings.hideAvatarsInInvites.value
                      ? null
                      : room.avatar,
                  name: displayName,
                  size: 96,
                  client: room.client,
                ),
                const SizedBox(height: 24),
                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
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

  double? screenWidth;
  double? screenHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Invite view?
    if (controller.room.membership == .invite) {
      return _buildInviteView(context);
    }

    final bottomSheetPadding = FluffyThemes.isColumnMode(context) ? 16.0 : 8.0;
    final scrollUpBannerEventId = controller.scrollUpBannerEventId;

    final wallpaperPath = AppSettings.wallpaperPath.value;

    if (screenWidth == null || screenHeight == null) {
      final view = View.of(context);
      screenWidth ??= view.physicalSize.width / view.devicePixelRatio;
      screenHeight ??= view.physicalSize.height / view.devicePixelRatio;
    }

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
      child: FutureBuilder(
        future: controller.loadTimelineFuture,
        builder: (BuildContext context, snapshot) {
          var appbarBottomHeight = 0.0;
          if (controller.room.pinnedEventIds.isNotEmpty) {
            appbarBottomHeight += ChatAppBarListTile.fixedHeight;
          }

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppSettings.enableFloatingAppBar.value
                    ? FloatingChatAppbar(
                        controller: controller,
                        appbarBottomHeight: appbarBottomHeight,
                        actions: _appBarActions(context)
                    )
                    : ChatLegacyAppBar(
                        controller: controller,
                        appbarBottomHeight: appbarBottomHeight,
                        actions: _appBarActions(context),
                    ),
            floatingActionButton: ValueListenableBuilder<bool>(
              valueListenable: controller.scrolledUpNotifier,
              builder: (context, scrolledUp, _) {
                final show =
                    (scrolledUp ||
                        controller.timeline?.allowNewEvent == false ||
                        controller.eventsToScrollBackTo.isNotEmpty) &&
                    controller.selectedEvents.isEmpty;
                if (!show) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 56.0),
                  child: FloatingActionButton(
                    onPressed: controller.scrollDown,
                    heroTag: null,
                    mini: true,
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurface,
                    child: const Icon(Icons.arrow_downward_outlined),
                  ),
                );
              },
            ),
            body: DropTarget(
              onDragDone: controller.onDragDone,
              onDragEntered: controller.onDragEntered,
              onDragExited: controller.onDragExited,
              child: Stack(
                children: <Widget>[
                  if (wallpaperPath.isNotEmpty)
                    Positioned.fill(
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: screenHeight,
                          maxWidth: screenWidth,
                          child: Opacity(
                            opacity: AppSettings.wallpaperOpacity.value,
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: AppSettings.wallpaperBlur.value,
                                sigmaY: AppSettings.wallpaperBlur.value,
                              ),
                              child: Image.file(
                                File(wallpaperPath),
                                fit: BoxFit.cover,
                                height: screenHeight,
                                width: screenWidth,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: controller.clearSingleSelectedEvent,
                      child: ChatEventList(
                        controller: controller,
                        showThreadRoots: controller.showThreadRoots,
                      ),
                    ),
                  ),
                  if (AppSettings.enableFloatingAppBar.value)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: MediaQuery.of(context).padding.top + kToolbarHeight + appbarBottomHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.colorScheme.surface,
                              theme.colorScheme.surface.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (controller.room.canSendDefaultMessages &&
                      controller.room.membership == Membership.join)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.surface.withValues(alpha: 0),
                                theme.colorScheme.surface.withValues(
                                  alpha: 0.6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: _MeasureSize(
                      onChange: (size) {
                        final oldHeight = controller.inputBarHeight.value;
                        final newHeight = size.height;
                        if (oldHeight == newHeight) return;
                        controller.inputBarHeight.value = newHeight + 8;

                        // Keep the list scrolled to the bottom if we were already
                        // there, otherwise the newly‑added input bar would cover a
                        // message.
                        final sc = controller.scrollController;
                        if (sc.hasClients && sc.offset <= 0.0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (sc.hasClients) sc.jumpTo(0.0);
                          });
                        }
                      },
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: bottomSheetPadding,
                            vertical: bottomSheetPadding / 2,
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: FluffyThemes.columnWidth * 2.5,
                              ),
                              child: controller.room.isExtinct
                                  ? (AppSettings.enableChatFrostedGlass.value
                                        ? _FloatingInputShell(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                Icons.chevron_right,
                                              ),
                                              label: Text(
                                                L10n.of(context).enterNewChat,
                                              ),
                                              onPressed:
                                                  controller.goToNewRoomAction,
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            label: Text(
                                              L10n.of(context).enterNewChat,
                                            ),
                                            onPressed:
                                                controller.goToNewRoomAction,
                                          ))
                                  : controller.room.canSendDefaultMessages &&
                                        controller.room.membership == .join
                                  ? (() {
                                      final inputChild =
                                          controller.room.isAbandonedDMRoom
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    foregroundColor:
                                                        theme.colorScheme.error,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.archive_outlined,
                                                  ),
                                                  onPressed:
                                                      controller.leaveChat,
                                                  label: Text(
                                                    L10n.of(context).leave,
                                                  ),
                                                ),
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.forum_outlined,
                                                  ),
                                                  onPressed:
                                                      controller.recreateChat,
                                                  label: Text(
                                                    L10n.of(context).reopenChat,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ReplyDisplay(controller),
                                                ChatInputRow(controller),
                                                ChatEmojiPicker(controller),
                                              ],
                                            );
                                      return AppSettings
                                              .enableChatFrostedGlass
                                              .value
                                          ? _FloatingInputShell(
                                              child: inputChild,
                                            )
                                          : Material(
                                              clipBehavior: Clip.hardEdge,
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHigh,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                side: BorderSide(
                                                  color: theme.dividerColor,
                                                ),
                                              ),
                                              child: inputChild,
                                            );
                                    })()
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (controller.dragging)
                    Container(
                      color: theme.scaffoldBackgroundColor.withAlpha(230),
                      alignment: Alignment.center,
                      child: const Icon(Icons.upload_outlined, size: 100),
                    ),

                  Positioned(
                    top:
                        MediaQuery.of(context).padding.top +
                        (AppBarTheme.of(context).toolbarHeight ??
                            kToolbarHeight) +
                        appbarBottomHeight +
                        6,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BackToCallButton(),
                          const MiniAudioPlayer(),
                          if (scrollUpBannerEventId != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton(
                                  onPressed: () {
                                    controller.scrollToEventId(
                                      scrollUpBannerEventId,
                                      null,
                                    );
                                    controller.discardScrollUpBannerEventId();
                                  },
                                  style: FilledButton.styleFrom(
                                    shadowColor: Colors.black,
                                    elevation: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.arrow_upward),
                                      SizedBox(width: 18),
                                      Text(
                                        L10n.of(context).jumpToLastReadMessage,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FloatingInputShell extends StatelessWidget {
  final Widget child;
  const _FloatingInputShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PhysicalModel(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.hardEdge,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: theme.colorScheme.surfaceContainerHigh.withAlpha(
                theme.brightness == Brightness.dark ? 160 : 190,
              ),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withAlpha(60),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(
                    theme.brightness == Brightness.dark ? 60 : 20,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.onChange, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _oldSize;

  _MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (newSize != _oldSize) {
      _oldSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChange(newSize);
      });
    }
  }
}
