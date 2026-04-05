import 'package:flutter/material.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/localized_exception_extension.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import 'package:extera_next/widgets/list_divider.dart';

class InviteDialog extends StatelessWidget {
  final Room room;
  const InviteDialog(this.room, {super.key});

  void accept(BuildContext context) async {
    await showFutureLoadingDialog(
      context: context,
      future: () async {
        final waitForRoom = room.client.waitForRoomInSync(room.id, join: true);
        await room.join();
        await waitForRoom;
      },
      exceptionContext: ExceptionContext.joinRoom,
    );
    Navigator.of(context, rootNavigator: true).pop();
  }

  void decline(BuildContext context) async {
    await showFutureLoadingDialog(context: context, future: room.leave);
    Navigator.of(context, rootNavigator: true).pop();
  }

  void block(BuildContext context) async {
    final userId = room
        .getState(EventTypes.RoomMember, room.client.userID!)
        ?.senderId;
    context.go('/rooms/settings/security/ignorelist', extra: userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppConfig.borderRadius);
    final membershipEvent = room.getState(
      EventTypes.RoomMember,
      room.client.userID!,
    );
    final topic = room.topic;
    final reason = membershipEvent?.content.tryGet<String>('reason');
    // final actualMembersCount =
    // (room.summary.mInvitedMemberCount ?? 0) +
    // (room.summary.mJoinedMemberCount ?? 0);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).newInvitation)),
      body: Column(
        mainAxisSize: .min,
        children: [
          Padding(
            padding: const .all(8),
            child: Material(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: borderRadius,
              clipBehavior: .hardEdge,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ListTile(
                    leading: Avatar(
                      mxContent: AppSettings.hideAvatarsInInvites.value
                          ? null
                          : room.avatar,
                      name: room.getLocalizedDisplayname(),
                      client: room.client,
                    ),
                    title: Text(room.getLocalizedDisplayname()),
                    subtitle: membershipEvent != null
                        ? Text(
                            L10n.of(
                              context,
                            ).youInvitedBy(membershipEvent.senderId),
                          )
                        : room.directChatMatrixID != null
                        ? Text(L10n.of(context).newChatRequest)
                        : Text(L10n.of(context).inviteGroupChat),
                  ),
                ],
              ),
            ),
          ),
          if (reason != null && reason.isNotEmpty)
            Padding(
              padding: const .all(8),
              child: Material(
                clipBehavior: .hardEdge,
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: borderRadius,
                child: ListTile(
                  title: Text(reason),
                  subtitle: Text(L10n.of(context).reason),
                  leading: const Icon(Icons.wysiwyg),
                ),
              ),
            ),
          if (topic.isNotEmpty)
            Padding(
              padding: const .all(8),
              child: Material(
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
                          decorationColor: theme.textTheme.bodyMedium!.color,
                        ),
                        onOpen: (url) =>
                            UrlLauncher(context, url.url).launchUrl(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const .all(8),
            child: Material(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: borderRadius,
              clipBehavior: .hardEdge,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.check,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      L10n.of(context).accept,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onTap: () => accept(context),
                  ),
                  const ListDivider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.errorContainer,
                      child: Icon(
                        Icons.close,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    title: Text(
                      L10n.of(context).decline,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    onTap: () => decline(context),
                  ),
                  const ListDivider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.error,
                      child: Icon(
                        Icons.block,
                        color: theme.colorScheme.onError,
                      ),
                    ),
                    title: Text(
                      L10n.of(context).block,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () => block(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
