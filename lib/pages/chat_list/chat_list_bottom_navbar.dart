import 'package:flutter/material.dart';

import 'package:badges/badges.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/pages/chat_list/chat_list.dart';
import 'package:extera_next/widgets/unread_rooms_badge.dart';
import '../../widgets/matrix.dart';

class ChatListBottomNavbar extends StatefulWidget {
  final ChatListController controller;
  final Widget? fab;

  const ChatListBottomNavbar(this.controller, {this.fab, super.key});

  @override
  State<ChatListBottomNavbar> createState() => _ChatListBottomNavbarState();
}

class _ChatListBottomNavbarState extends State<ChatListBottomNavbar> {
  ChatListController get _c => widget.controller;

  List<Room> spaces = [];
  Map<String, Room> spaceDelegateCandidates = {};

  @override
  void initState() {
    final client = Matrix.of(context).client;

    spaces = client.rooms.where((r) => r.isSpace).toList();
    for (final space in spaces) {
      for (final spaceChild in space.spaceChildren) {
        final roomId = spaceChild.roomId;
        if (roomId == null) continue;
        spaceDelegateCandidates[roomId] = space;
      }
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filters = [
      if (AppSettings.separateChatTypes.value)
        ActiveFilter.messages
      else
        ActiveFilter.allChats,
      if (AppSettings.separateChatTypes.value) ActiveFilter.groups,
      ActiveFilter.unread,
      if (AppSettings.enableInvitesTab.value) ActiveFilter.invites,
      if (spaceDelegateCandidates.isNotEmpty &&
          !_c.widget.displayNavigationRail)
        ActiveFilter.spaces,
      if (AppSettings.enablePeopleTab.value) ActiveFilter.people,
    ];

    final filterLambdas = {
      ActiveFilter.allChats: (Room room) =>(!AppSettings.enableInvitesTab.value || !room.membership.isInvite),
      ActiveFilter.messages: (Room room) => (!AppSettings.enableInvitesTab.value || !room.membership.isInvite) && room.isDirectChat,
      ActiveFilter.groups: (Room room) => (!AppSettings.enableInvitesTab.value || !room.membership.isInvite) && !room.isDirectChat,
      ActiveFilter.unread: (Room room) => room.isUnread,
      ActiveFilter.invites: (Room room) => room.membership.isInvite,
      ActiveFilter.spaces: (Room room) => false,
      ActiveFilter.people: (Room room) => false,
    };

    return Row(
      mainAxisSize: .max,
      spacing: 8,
      children: [
        Flexible(
          flex: 1,
          child: Material(
            borderRadius: BorderRadius.circular(128),
            clipBehavior: Clip.hardEdge,
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: filters.map((filter) {
                  final isActive = _c.activeFilter == filter;

                  final backgroundColor = isActive
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent;

                  final foregroundColor = isActive
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant;

                  return Expanded(
                    key: ValueKey(filter),
                    child: Padding(
                      padding: const .all(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(124),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: () => _c.setActiveFilter(filter),
                            borderRadius: BorderRadius.circular(124),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isActive)
                                    Icon(
                                      filter.toIconData(false),
                                      size: 20,
                                      color: foregroundColor,
                                    )
                                  else
                                    UnreadRoomsBadge(
                                      filter: filterLambdas[filter]!,
                                      badgePosition: BadgePosition.topEnd(),
                                      child: Icon(
                                        filter.toIconData(true),
                                        size: 20,
                                        color: foregroundColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        widget.fab ?? const SizedBox.shrink(),
      ],
    );
  }
}
