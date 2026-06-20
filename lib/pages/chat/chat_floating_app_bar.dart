import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/pages/chat/chat_app_bar_title.dart';
import 'package:extera_next/pages/chat/pinned_events.dart';
import 'package:extera_next/utils/stream_extension.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/unread_rooms_badge.dart';

class FloatingChatAppbar extends StatelessWidget implements PreferredSizeWidget {
  final ChatController controller;
  final double appbarBottomHeight;
  final List<Widget> actions;

  const FloatingChatAppbar({
    super.key,
    required this.controller,
    required this.appbarBottomHeight,
    required this.actions,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + appbarBottomHeight + 8);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
              child: (() {
                  final appBar = AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  actionsIconTheme: IconThemeData(
                  color: controller.selectedEvents.isEmpty
                      ? null
                      : theme.colorScheme.tertiary,
                  ),
                  automaticallyImplyLeading: false,
                  centerTitle: AppSettings.enableAppBarCenterTitle.value,
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
                          stream: Matrix.of(context).client.onSync.stream
                              .where((s) => s.hasRoomUpdate)
                              .rateLimit(const Duration(seconds: 1)),
                          builder: (context, _) => UnreadRoomsBadge(
                            filter: (r) => r.id != controller.roomId,
                            badgePosition: .topEnd(top: 4, end: 8),
                            child: const Center(child: BackButton()),
                          ),
                        ),
                  titleSpacing: FluffyThemes.isColumnMode(context) ? 24 : 0,
                  title: ChatAppBarTitle(controller),
                  actions: actions,
                  bottom: PreferredSize(
                    preferredSize: Size.fromHeight(appbarBottomHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [PinnedEvents(controller)],
                    ),
                  ),
              );
              return AppSettings.enableChatFrostedGlass.value
              ? _FloatingAppBar(child: appBar)
              : Material(
                  clipBehavior: Clip.hardEdge,
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  child: appBar,
                  );
              })(),
            ),
      );
  }
}

class _FloatingAppBar extends StatelessWidget {
  final Widget child;

  const _FloatingAppBar({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withAlpha(
                theme.brightness == Brightness.dark ? 180 : 200,
              ),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(80),
                  width: 0.5,
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}