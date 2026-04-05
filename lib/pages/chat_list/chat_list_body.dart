import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat_list/chat_list.dart';
import 'package:extera_next/pages/chat_list/chat_list_item.dart';
import 'package:extera_next/pages/chat_list/chat_list_legacy_header.dart';
import 'package:extera_next/pages/chat_list/dummy_chat_list_item.dart';
import 'package:extera_next/pages/chat_list/search_title.dart';
import 'package:extera_next/pages/chat_list/space_view.dart';
import 'package:extera_next/pages/chat_list/status_msg_list.dart';
import 'package:extera_next/pages/dialer/back_to_call_button.dart';
import 'package:extera_next/shortcuts/chat_list/chat_list_shortcuts.dart';
import 'package:extera_next/utils/show_profile.dart';
import 'package:extera_next/utils/stream_extension.dart';
import 'package:extera_next/widgets/adaptive_dialogs/public_room_dialog.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/mini_audio_player.dart';
import '../../config/themes.dart';
import '../../widgets/matrix.dart';
import 'chat_list_header.dart';

class ChatListViewBody extends StatelessWidget {
  final ChatListController controller;

  const ChatListViewBody(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final client = Matrix.of(context).client;
    final activeSpace = controller.activeSpaceId;
    if (activeSpace != null) {
      return SpaceView(
        key: ValueKey(activeSpace),
        spaceId: activeSpace,
        onBack: controller.clearActiveSpace,
        onChatTab: (room) => controller.onChatTap(room),
        onChatContext: (room, context) =>
            controller.chatContextAction(room, context),
        activeChat: controller.activeChat,
        toParentSpace: controller.setActiveSpace,
      );
    }
    final spaces = client.rooms.where((r) => r.isSpace);
    final spaceDelegateCandidates = <String, Room>{};
    for (final space in spaces) {
      for (final spaceChild in space.spaceChildren) {
        final roomId = spaceChild.roomId;
        if (roomId == null) continue;
        spaceDelegateCandidates[roomId] = space;
      }
    }

    final publicRooms = controller.roomSearchResult?.chunk
        .where((room) => room.roomType != 'm.space')
        .toList();
    final publicSpaces = controller.roomSearchResult?.chunk
        .where((room) => room.roomType == 'm.space')
        .toList();
    final userSearchResult = controller.userSearchResult;
    const dummyChatCount = 4;
    final filter = controller.searchController.text.toLowerCase();

    return StreamBuilder(
      key: ValueKey(client.userID.toString()),
      stream: client.onSync.stream
          .where((s) => s.hasRoomUpdate)
          .rateLimit(const Duration(seconds: 1)),
      builder: (context, _) {
        final rooms = controller.filteredRooms;

        return ChatListShortcuts(
          onPreviousChat: () {
            if (controller.activeChat == null) return;
            var i = rooms.indexWhere(
              (room) => room.id == controller.activeChat,
            );
            if (i - 1 < 0) i = rooms.length - 1;
            controller.onChatTap(rooms[i - 1]);
          },
          onNextChat: () {
            if (controller.activeChat == null) return;
            var i = rooms.indexWhere(
              (room) => room.id == controller.activeChat,
            );
            if (i >= rooms.length) i = 0;
            controller.onChatTap(rooms[i + 1]);
          },
          child: SafeArea(
            child: CustomScrollView(
              controller: controller.scrollController,
              slivers: [
                if (AppSettings.useLegacyChatListAppBar.value)
                  ChatListLegacyHeader(controller: controller)
                else
                  ChatListHeader(controller: controller),
                SliverList(
                  delegate: SliverChildListDelegate([
                    if (controller.isSearchMode) ...[
                      Padding(
                        padding: const .all(8),
                        child: SearchTitle(
                          title: L10n.of(context).publicRooms,
                          icon: const Icon(Icons.explore_outlined),
                        ),
                      ),
                      PublicRoomsHorizontalList(publicRooms: publicRooms),
                      Padding(
                        padding: const .all(8),
                        child: SearchTitle(
                          title: L10n.of(context).publicSpaces,
                          icon: const Icon(Icons.workspaces_outlined),
                        ),
                      ),
                      PublicRoomsHorizontalList(publicRooms: publicSpaces),
                      Padding(
                        padding: const .all(8),
                        child: SearchTitle(
                          title: L10n.of(context).users,
                          icon: const Icon(Icons.group_outlined),
                        ),
                      ),
                      AnimatedContainer(
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(),
                        height:
                            userSearchResult == null ||
                                userSearchResult.results.isEmpty
                            ? 0
                            : 106,
                        duration: FluffyThemes.animationDuration,
                        curve: FluffyThemes.animationCurve,
                        child: userSearchResult == null
                            ? null
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: userSearchResult.results.length,
                                itemBuilder: (context, i) => _SearchItem(
                                  title:
                                      userSearchResult.results[i].displayName ??
                                      userSearchResult
                                          .results[i]
                                          .userId
                                          .localpart ??
                                      L10n.of(context).unknownDevice,
                                  avatar: userSearchResult.results[i].avatarUrl,
                                  onPressed: () => showProfile(
                                    context: context,
                                    profile: userSearchResult.results[i],
                                  ),
                                ),
                              ),
                      ),
                    ],
                    if (!controller.isSearchMode &&
                        AppSettings.showPresences.value)
                      GestureDetector(
                        onLongPress: () => controller.dismissStatusList(),
                        child: StatusMessageList(
                          onStatusEdit: controller.setStatus,
                        ),
                      ),
                    if (!FluffyThemes.isColumnMode(context)) ...[
                      const BackToCallButton(),
                      const MiniAudioPlayer(),
                    ],
                    if (controller.isSearchMode)
                      Padding(
                        padding: const .all(8),
                        child: SearchTitle(
                          title: L10n.of(context).chats,
                          icon: const Icon(Icons.forum_outlined),
                        ),
                      ),
                    if (client.prevBatch != null &&
                        rooms.isEmpty &&
                        !controller.isSearchMode) ...[
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DummyChatListItem(
                                    opacity: 0.5,
                                    animate: false,
                                  ),
                                  DummyChatListItem(
                                    opacity: 0.3,
                                    animate: false,
                                  ),
                                ],
                              ),
                              Icon(
                                CupertinoIcons.chat_bubble_text_fill,
                                size: 128,
                                color: theme.colorScheme.secondary,
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              client.rooms.isEmpty
                                  ? L10n.of(context).noChatsFoundHere
                                  : L10n.of(context).noMoreChatsFound,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ]),
                ),
                if (client.prevBatch == null)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => DummyChatListItem(
                        opacity: (dummyChatCount - i) / dummyChatCount,
                        animate: true,
                      ),
                      childCount: dummyChatCount,
                    ),
                  ),
                if (client.prevBatch != null)
                  SliverList.builder(
                    itemCount: rooms.length,
                    itemBuilder: (BuildContext context, int i) {
                      final room = rooms[i];
                      final space = spaceDelegateCandidates[room.id];
                      return ChatListItem(
                        room,
                        space: space,
                        key: Key('chat_list_item_${room.id}'),
                        filter: filter,
                        onTap: () => controller.onChatTap(room),
                        onLongPress: (context) =>
                            controller.chatContextAction(room, context, space),
                        activeChat: controller.activeChat == room.id,
                        firstElement: i == 0,
                        lastElement: rooms.length - 1 == i,
                      );
                    },
                  ),
                SliverToBoxAdapter(child: const SizedBox(height: 172)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PublicRoomsHorizontalList extends StatelessWidget {
  const PublicRoomsHorizontalList({super.key, required this.publicRooms});

  final List<PublicRoomsChunk>? publicRooms;

  @override
  Widget build(BuildContext context) {
    final publicRooms = this.publicRooms;
    return AnimatedContainer(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      height: publicRooms == null || publicRooms.isEmpty ? 0 : 106,
      duration: FluffyThemes.animationDuration,
      curve: FluffyThemes.animationCurve,
      child: publicRooms == null
          ? null
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: publicRooms.length,
              itemBuilder: (context, i) => _SearchItem(
                title:
                    publicRooms[i].name ??
                    publicRooms[i].canonicalAlias?.localpart ??
                    L10n.of(context).group,
                avatar: publicRooms[i].avatarUrl,
                onPressed: () => showAdaptiveDialog(
                  context: context,
                  useRootNavigator: false,
                  builder: (c) => PublicRoomDialog(
                    roomAlias:
                        publicRooms[i].canonicalAlias ?? publicRooms[i].roomId,
                    chunk: publicRooms[i],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SearchItem extends StatelessWidget {
  final String title;
  final Uri? avatar;
  final void Function() onPressed;

  const _SearchItem({
    required this.title,
    this.avatar,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    child: SizedBox(
      width: 84,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Avatar(mxContent: avatar, name: title),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}
