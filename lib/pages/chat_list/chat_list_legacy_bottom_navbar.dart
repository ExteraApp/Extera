import 'dart:math';

import 'package:flutter/material.dart';

import 'package:badges/badges.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/pages/chat_list/chat_list.dart';
import 'package:extera_next/widgets/unread_rooms_badge.dart';
import '../../widgets/matrix.dart';

class ChatListLegacyBottomNavbar extends StatelessWidget {
  final ChatListController controller;

  const ChatListLegacyBottomNavbar(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final theme = Theme.of(context);

    final spaces = client.rooms.where((r) => r.isSpace);
    final spaceDelegateCandidates = <String, Room>{};
    for (final space in spaces) {
      for (final spaceChild in space.spaceChildren) {
        final roomId = spaceChild.roomId;
        if (roomId == null) continue;
        spaceDelegateCandidates[roomId] = space;
      }
    }

    final filters = [
      if (AppSettings.separateChatTypes.value)
        ActiveFilter.messages
      else
        ActiveFilter.allChats,
      ActiveFilter.groups,
      ActiveFilter.unread,
      if (spaceDelegateCandidates.isNotEmpty &&
          !controller.widget.displayNavigationRail)
        ActiveFilter.spaces,
    ];

    final filterLambdas = {
      ActiveFilter.allChats: (Room room) => true,
      ActiveFilter.messages: (Room room) => room.isDirectChat,
      ActiveFilter.groups: (Room room) => !room.isDirectChat,
      ActiveFilter.unread: (Room room) => room.isUnread,
      ActiveFilter.spaces: (Room room) => false,
    };

    return BottomNavigationBar(
      currentIndex: max(0, filters.indexOf(controller.activeFilter)),
      backgroundColor: theme.colorScheme.surfaceContainer,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.secondary,
      enableFeedback: true,
      onTap: (index) {
        controller.setActiveFilter(filters[index]);
      },
      items: filters
          .map(
            (filter) => BottomNavigationBarItem(
              icon: UnreadRoomsBadge(
                filter: filterLambdas[filter]!,
                badgePosition: BadgePosition.topEnd(),
                child: Icon(filter.toIconData(true)),
              ),
              activeIcon: Icon(filter.toIconData(false)),
              label: filter.toLocalizedString(context),
            ),
          )
          .toList(),
    );
  }
}
