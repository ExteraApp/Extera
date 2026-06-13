import 'package:flutter/material.dart';

import 'package:badges/badges.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/pages/chat_list/chat_list.dart';
import 'package:extera_next/widgets/unread_rooms_badge.dart';
import '../../widgets/matrix.dart';

class ChatListLegacyBottomNavbar extends StatefulWidget {
  final ChatListController controller;

  const ChatListLegacyBottomNavbar(this.controller, {super.key});

  @override
  State<ChatListLegacyBottomNavbar> createState() =>
      _ChatListLegacyBottomNavbarState();
}

class _ChatListLegacyBottomNavbarState
    extends State<ChatListLegacyBottomNavbar> {
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

    return NavigationBar(
      height: 64,
      onDestinationSelected: (filterIndex) {
        setState(() {
          _c.setActiveFilter(filters[filterIndex]);
        });
      },
      selectedIndex: filters.indexOf(_c.activeFilter),
      destinations: filters.map((filter) {
        return NavigationDestination(
          selectedIcon: Icon(filter.toIconData(false)),
          icon: UnreadRoomsBadge(
            filter: filterLambdas[filter]!,
            badgePosition: BadgePosition.topEnd(),
            child: Icon(filter.toIconData(true)),
          ),
          label: filter.toLocalizedString(context),
          key: ValueKey(filter.name),
        );
      }).toList(),
    );
  }
}
