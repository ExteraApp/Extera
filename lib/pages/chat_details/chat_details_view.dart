import 'package:flutter/material.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat_details/chat_details.dart';
import 'package:extera_next/pages/chat_details/participant_list_item.dart';
import 'package:extera_next/utils/fluffy_share.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/chat_settings_popup_menu.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';
import 'package:extera_next/widgets/list_divider.dart';
import 'package:extera_next/widgets/matrix.dart';
import '../../utils/url_launcher.dart';
import '../../widgets/mxc_image_viewer.dart';
import '../../widgets/qr_code_viewer.dart';

class ChatDetailsView extends StatelessWidget {
  final ChatDetailsController controller;

  const ChatDetailsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final room = Matrix.of(context).client.getRoomById(controller.roomId!);
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(L10n.of(context).oopsSomethingWentWrong)),
        body: Center(
          child: Text(L10n.of(context).youAreNoLongerParticipatingInThisChat),
        ),
      );
    }

    final borderRadius = BorderRadius.circular(AppConfig.borderRadius);

    final directChatMatrixID = room.directChatMatrixID;
    final roomAvatar = room.avatar;

    return StreamBuilder(
      stream: room.client.onRoomState.stream.where(
        (update) => update.roomId == room.id,
      ),
      builder: (context, snapshot) {
        var members = room.getParticipants().toList()
          ..sort((b, a) => a.powerLevel.compareTo(b.powerLevel));
        members = members.take(10).toList();
        final actualMembersCount =
            (room.summary.mInvitedMemberCount ?? 0) +
            (room.summary.mJoinedMemberCount ?? 0);
        final canRequestMoreMembers = members.length < actualMembersCount;
        final displayname = room.getLocalizedDisplayname(
          MatrixLocals(L10n.of(context)),
        );
        return Scaffold(
          appBar: AppBar(
            leading:
                controller.widget.embeddedCloseButton ??
                const Center(child: BackButton()),
            elevation: theme.appBarTheme.elevation,
            actions: <Widget>[
              if (room.canonicalAlias.isNotEmpty)
                IconButton(
                  tooltip: L10n.of(context).share,
                  icon: const Icon(Icons.qr_code_rounded),
                  onPressed: () =>
                      showQrCodeViewer(context, room.canonicalAlias),
                )
              else if (directChatMatrixID != null)
                IconButton(
                  tooltip: L10n.of(context).share,
                  icon: const Icon(Icons.qr_code_rounded),
                  onPressed: () =>
                      showQrCodeViewer(context, directChatMatrixID),
                ),
              if (controller.widget.embeddedCloseButton == null)
                ChatSettingsPopupMenu(room, false),
            ],
            title: Text(L10n.of(context).chatDetails),
            backgroundColor: theme.appBarTheme.backgroundColor,
          ),
          body: MaxWidthBody(
            child: Padding(
              padding: const .symmetric(horizontal: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Stack(
                          children: [
                            Hero(
                              tag: controller.widget.embeddedCloseButton != null
                                  ? 'embedded_content_banner'
                                  : 'content_banner',
                              child: Avatar(
                                mxContent: room.avatar,
                                name: displayname,
                                size: Avatar.defaultSize * 2.5,
                                onTap: roomAvatar != null
                                    ? () => showDialog(
                                        context: context,
                                        useRootNavigator: false,
                                        builder: (_) =>
                                            MxcImageViewer(roomAvatar),
                                      )
                                    : null,
                              ),
                            ),
                            if (!room.isDirectChat &&
                                room.canChangeStateEvent(EventTypes.RoomAvatar))
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: FloatingActionButton.small(
                                  onPressed: controller.setAvatarAction,
                                  heroTag: null,
                                  child: const Icon(Icons.camera_alt_outlined),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () => room.isDirectChat
                                  ? null
                                  : room.canChangeStateEvent(
                                      EventTypes.RoomName,
                                    )
                                  ? controller.setDisplaynameAction()
                                  : FluffyShare.share(
                                      displayname,
                                      context,
                                      copyOnly: true,
                                    ),
                              icon: Icon(
                                room.isDirectChat
                                    ? Icons.chat_bubble_outline
                                    : room.canChangeStateEvent(
                                        EventTypes.RoomName,
                                      )
                                    ? Icons.edit_outlined
                                    : Icons.copy_outlined,
                                size: 16,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.onSurface,
                                iconColor: theme.colorScheme.onSurface,
                              ),
                              label: Text(
                                room.isDirectChat
                                    ? L10n.of(context).directChat
                                    : displayname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => room.isDirectChat
                                  ? null
                                  : context.push(
                                      '/rooms/${controller.roomId}/details/members',
                                    ),
                              icon: const Icon(Icons.group_outlined, size: 14),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.secondary,
                                iconColor: theme.colorScheme.secondary,
                              ),
                              label: Text(
                                L10n.of(
                                  context,
                                ).countParticipants(actualMembersCount),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                //    style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (room.canChangeStateEvent(EventTypes.RoomTopic) ||
                      room.topic.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Material(
                      clipBehavior: .hardEdge,
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: borderRadius,
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              L10n.of(context).chatDescription,
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing:
                                room.canChangeStateEvent(EventTypes.RoomTopic)
                                ? IconButton(
                                    onPressed: controller.setTopicAction,
                                    tooltip: L10n.of(
                                      context,
                                    ).setChatDescription,
                                    icon: const Icon(Icons.edit_outlined),
                                  )
                                : null,
                          ),
                          ListTile(
                            title: SelectableLinkify(
                              text: room.topic.isEmpty
                                  ? L10n.of(context).noChatDescriptionYet
                                  : room.topic,
                              textScaleFactor: MediaQuery.textScalerOf(
                                context,
                              ).scale(1),
                              options: const LinkifyOptions(humanize: false),
                              linkStyle: const TextStyle(
                                color: Colors.blueAccent,
                                decorationColor: Colors.blueAccent,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: room.topic.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: theme.textTheme.bodyMedium!.color,
                                decorationColor:
                                    theme.textTheme.bodyMedium!.color,
                              ),
                              onOpen: (url) =>
                                  UrlLauncher(context, url.url).launchUrl(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                  if (room.canonicalAlias.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Material(
                      clipBehavior: .hardEdge,
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: borderRadius,
                      child: ListTile(
                        title: Text(room.canonicalAlias),
                        subtitle: Text(L10n.of(context).roomAddress),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          child: Icon(
                            Icons.link,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        trailing: const Icon(Icons.qr_code),
                        onTap: () =>
                            showQrCodeViewer(context, room.canonicalAlias),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Material(
                    clipBehavior: .hardEdge,
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: borderRadius,
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.secondary,
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
                          title: Text(L10n.of(context).chatThreads),
                          subtitle: Text(
                            L10n.of(context).chatThreadsDescription,
                          ),
                          onTap: () =>
                              context.push('/rooms/${room.id}/threads'),
                          trailing: const Icon(Icons.chevron_right_outlined),
                        ),
                        const ListDivider(),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.tertiary,
                            child: Icon(
                              Icons.insert_emoticon_outlined,
                              color: theme.colorScheme.onTertiary,
                            ),
                          ),
                          title: Text(L10n.of(context).customEmojisAndStickers),
                          subtitle: Text(L10n.of(context).setCustomEmotes),
                          onTap: controller.goToEmoteSettings,
                          trailing: const Icon(Icons.chevron_right_outlined),
                        ),
                        const ListDivider(),
                        if (!room.isDirectChat) ...[
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: Icon(
                                Icons.shield_outlined,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            title: Text(L10n.of(context).accessAndVisibility),
                            subtitle: Text(
                              L10n.of(context).accessAndVisibilityDescription,
                            ),
                            onTap: () => context.push(
                              '/rooms/${room.id}/details/access',
                            ),
                            trailing: const Icon(Icons.chevron_right_outlined),
                          ),
                          const ListDivider(),
                        ],
                        if (!room.isDirectChat) ...[
                          ListTile(
                            title: Text(L10n.of(context).chatPermissions),
                            subtitle: Text(
                              L10n.of(context).whoCanPerformWhichAction,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.tertiary,
                              child: Icon(
                                Icons.edit_attributes_outlined,
                                color: theme.colorScheme.onTertiary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_outlined),
                            onTap: () => context.push(
                              '/rooms/${room.id}/details/permissions',
                            ),
                          ),
                          const ListDivider(),
                        ],
                        ListTile(
                          title: Text(L10n.of(context).widgets),
                          subtitle: Text(L10n.of(context).widgetsDescription),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.secondary,
                            child: Icon(
                              Icons.widgets_outlined,
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_outlined),
                          onTap: () =>
                              context.push('/rooms/${room.id}/details/widgets'),
                        ),
                        const ListDivider(),
                        ListTile(
                          title: Text(L10n.of(context).chatPrivacy),
                          subtitle: Text(
                            L10n.of(context).chatPrivacyDescription,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(
                              Icons.lock_outline,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_outlined),
                          onTap: () =>
                              context.push('/rooms/${room.id}/details/privacy'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    clipBehavior: .hardEdge,
                    borderRadius: borderRadius,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            L10n.of(
                              context,
                            ).countParticipants(actualMembersCount),
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount:
                              members.length + (canRequestMoreMembers ? 1 : 0),
                          itemBuilder: (BuildContext context, int i) =>
                              i < members.length
                              ? ParticipantListItem(members[i])
                              : ListTile(
                                  title: Text(
                                    L10n.of(context).loadCountMoreParticipants(
                                      (actualMembersCount - members.length),
                                    ),
                                    style: TextStyle(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        theme.colorScheme.surfaceContainerHigh,
                                    child: const Icon(
                                      Icons.group_outlined,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onTap: () => context.push(
                                    '/rooms/${controller.roomId!}/details/members',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_outlined,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
