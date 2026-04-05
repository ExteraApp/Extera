import 'package:flutter/material.dart' hide Visibility;

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:extera_next/utils/fluffy_share.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';
import 'package:extera_next/widgets/list_divider.dart';

class ChatAccessSettingsPageView extends StatelessWidget {
  final ChatAccessSettingsController controller;
  const ChatAccessSettingsPageView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppConfig.borderRadius);

    final room = controller.room;
    return Scaffold(
      appBar: AppBar(
        leading: const Center(child: BackButton()),
        title: Text(L10n.of(context).accessAndVisibility),
      ),
      body: MaxWidthBody(
        child: Padding(
          padding: const .symmetric(horizontal: 8),
          child: StreamBuilder<Object>(
            stream: room.client.onRoomState.stream.where(
              (update) => update.roomId == controller.room.id,
            ),
            builder: (context, snapshot) {
              final canonicalAlias = room.canonicalAlias;
              final altAliases =
                  room
                      .getState(EventTypes.RoomCanonicalAlias)
                      ?.content
                      .tryGetList<String>('alt_aliases') ??
                  [];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    borderRadius: borderRadius,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            L10n.of(context).visibilityOfTheChatHistory,
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        RadioGroup<HistoryVisibility>(
                          groupValue: room.historyVisibility,
                          onChanged:
                              controller.historyVisibilityLoading ||
                                  !room.canChangeHistoryVisibility
                              ? (_) {}
                              : controller.setHistoryVisibility,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final historyVisibility
                                  in HistoryVisibility.values)
                                RadioListTile<HistoryVisibility>.adaptive(
                                  title: Text(
                                    historyVisibility.getLocalizedString(
                                      MatrixLocals(L10n.of(context)),
                                    ),
                                  ),
                                  enabled: room.canChangeHistoryVisibility,
                                  value: historyVisibility,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    borderRadius: borderRadius,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            L10n.of(context).whoIsAllowedToJoinThisGroup,
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        RadioGroup(
                          groupValue: room.joinRules,
                          onChanged: controller.setJoinRule,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final joinRule
                                  in controller.availableJoinRules)
                                if (joinRule != JoinRules.private)
                                  RadioListTile<JoinRules>.adaptive(
                                    enabled:
                                        !controller.joinRulesLoading &&
                                        room.canChangeJoinRules,
                                    title: Text(
                                      joinRule.localizedString(
                                        L10n.of(context),
                                        controller.knownSpaceParents,
                                      ),
                                    ),
                                    value: joinRule,
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    borderRadius: borderRadius,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Column(
                      children: [
                        if ({
                          JoinRules.public,
                          JoinRules.knock,
                        }.contains(room.joinRules)) ...[
                          ListTile(
                            title: Text(
                              L10n.of(context).areGuestsAllowedToJoin,
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          RadioGroup(
                            groupValue: room.guestAccess,
                            onChanged: controller.setGuestAccess,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final guestAccess in GuestAccess.values)
                                  RadioListTile<GuestAccess>.adaptive(
                                    enabled:
                                        !controller.guestAccessLoading &&
                                        room.canChangeGuestAccess,
                                    title: Text(
                                      guestAccess.getLocalizedString(
                                        MatrixLocals(L10n.of(context)),
                                      ),
                                    ),
                                    value: guestAccess,
                                  ),
                              ],
                            ),
                          ),
                          const ListDivider(),
                          ListTile(
                            title: Text(
                              L10n.of(context).publicChatAddresses,
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_outlined),
                              tooltip: L10n.of(context).createNewAddress,
                              onPressed: controller.addAlias,
                            ),
                          ),
                          if (canonicalAlias.isNotEmpty)
                            _AliasListTile(
                              alias: canonicalAlias,
                              onDelete:
                                  room.canChangeStateEvent(
                                    EventTypes.RoomCanonicalAlias,
                                  )
                                  ? () => controller.deleteAlias(canonicalAlias)
                                  : null,
                              isCanonicalAlias: true,
                            ),
                          for (final alias in altAliases)
                            _AliasListTile(
                              alias: alias,
                              onDelete:
                                  room.canChangeStateEvent(
                                    EventTypes.RoomCanonicalAlias,
                                  )
                                  ? () => controller.deleteAlias(alias)
                                  : null,
                            ),
                          FutureBuilder(
                            future: room.client.getLocalAliases(room.id),
                            builder: (context, snapshot) {
                              final localAddresses = snapshot.data;
                              if (localAddresses == null) {
                                return const SizedBox.shrink();
                              }
                              localAddresses.remove(room.canonicalAlias);
                              localAddresses.removeWhere(
                                (alias) => altAliases.contains(alias),
                              );
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: localAddresses
                                    .map(
                                      (alias) => _AliasListTile(
                                        alias: alias,
                                        published: false,
                                        onDelete: () =>
                                            controller.deleteAlias(alias),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          const ListDivider(),
                          FutureBuilder(
                            future: room.client.getRoomVisibilityOnDirectory(
                              room.id,
                            ),
                            builder: (context, snapshot) =>
                                SwitchListTile.adaptive(
                                  value: snapshot.data == Visibility.public,
                                  title: Text(
                                    L10n.of(
                                      context,
                                    ).chatCanBeDiscoveredViaSearchOnServer(
                                      room.client.userID!.domain!,
                                    ),
                                  ),
                                  onChanged:
                                      controller.setChatVisibilityOnDirectory,
                                ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    borderRadius: borderRadius,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(L10n.of(context).globalChatId),
                          subtitle: SelectableText(room.id),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () =>
                                FluffyShare.share(room.id, context),
                          ),
                        ),
                        const ListDivider(),
                        ListTile(
                          title: Text(L10n.of(context).roomVersion),
                          subtitle: SelectableText(
                            room
                                    .getState(EventTypes.RoomCreate)!
                                    .content
                                    .tryGet<String>('room_version') ??
                                'Unknown',
                          ),
                          trailing: room.canSendEvent(EventTypes.RoomTombstone)
                              ? IconButton(
                                  icon: const Icon(Icons.upgrade_outlined),
                                  onPressed: controller.updateRoomAction,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AliasListTile extends StatelessWidget {
  const _AliasListTile({
    required this.alias,
    required this.onDelete,
    this.isCanonicalAlias = false,
    this.published = true,
  });

  final String alias;
  final void Function()? onDelete;
  final bool isCanonicalAlias;
  final bool published;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: isCanonicalAlias
          ? const Icon(Icons.star)
          : const Icon(Icons.link_outlined),
      title: InkWell(
        onTap: () => FluffyShare.share('https://matrix.to/#/$alias', context),
        child: SelectableText(
          alias,
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary,
            color: theme.colorScheme.primary,
            fontSize: 14,
          ),
        ),
      ),
      trailing: onDelete != null
          ? IconButton(
              color: theme.colorScheme.error,
              icon: const Icon(Icons.delete_outlined),
              onPressed: onDelete,
            )
          : null,
    );
  }
}

extension JoinRulesDisplayString on JoinRules {
  String localizedString(L10n l10n, Set<Room> spaceParents) {
    switch (this) {
      case JoinRules.public:
        return l10n.anyoneCanJoin;
      case JoinRules.invite:
        return l10n.invitedUsersOnly;
      case JoinRules.knock:
        return l10n.usersMustKnock;
      case JoinRules.private:
        return l10n.noOneCanJoin;
      case JoinRules.restricted:
        return l10n.spaceMemberOf(
          spaceParents
              .map((space) => space.getLocalizedDisplayname(MatrixLocals(l10n)))
              .join(', '),
        );
      case JoinRules.knockRestricted:
        return l10n.spaceMemberOfCanKnock(
          spaceParents
              .map((space) => space.getLocalizedDisplayname(MatrixLocals(l10n)))
              .join(', '),
        );
    }
  }
}
