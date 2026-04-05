import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat_list/chat_list_item.dart';
import 'package:extera_next/pages/profile/profile.dart';
import 'package:extera_next/utils/date_time_extension.dart';
import 'package:extera_next/utils/stream_extension.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';
import 'package:extera_next/widgets/list_divider.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/mxc_image.dart';
import 'package:extera_next/widgets/mxc_image_viewer.dart';
import 'package:extera_next/widgets/presence_builder.dart';

class ProfileView extends StatelessWidget {
  final ProfileController controller;

  const ProfileView(this.controller, {super.key});

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool destructive = false,
  }) {
    var style = ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.borderRadius - 4),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
    );

    if (destructive) {
      style = style.copyWith(
        backgroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.errorContainer,
        ),
        foregroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
    }

    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, textScaler: const TextScaler.linear(0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildMutualChatList({
    required BuildContext context,
    required String userId,
  }) {
    final client = Matrix.of(context).client;

    return StreamBuilder(
      key: ValueKey(userId),
      stream: client.onSync.stream
          .where((s) => s.hasRoomUpdate)
          .rateLimit(const Duration(seconds: 1)),
      builder: (context, _) {
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
          itemCount: controller.mutualRooms.length,
          itemBuilder: (BuildContext context, int i) {
            final room = controller.mutualRooms[i];
            return ChatListItem(
              room,
              key: Key('mutual_chat_list_item_${room.id}'),
              // filter: filter,
              onTap: () => controller.onChatTap(room),
            );
          },
        );
      },
    );
  }

  Widget _buildBannerPlaceholder(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.widget.profile;
    final client = Matrix.of(context).client;
    final borderRadius = BorderRadius.circular(AppConfig.borderRadius);
    final displayname =
        profile.displayName ??
        profile.userId.localpart ??
        L10n.of(context).user;
    final theme = Theme.of(context);
    final avatar = profile.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: BackButton(onPressed: Navigator.of(context).pop),
        ),
        title: Text(displayname),
      ),
      body: MaxWidthBody(
        withoutVerticalPadding: true,
        withoutVisibleBorder: true,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const .all(8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Banner image (background layer) - fills entire Stack height
                  if (controller.bannerUrl != null)
                    Positioned.fill(
                      child: MxcImage(
                        uri: controller.bannerUrl,
                        fit: BoxFit.cover,
                        isThumbnail: false,
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadius,
                        ),
                        placeholder: _buildBannerPlaceholder,
                      ),
                    )
                  else
                    Positioned.fill(child: _buildBannerPlaceholder(context)),

                  Padding(
                    padding: const .all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PresenceBuilder(
                          userId: profile.userId,
                          client: Matrix.of(context).client,
                          builder: (context, presence) {
                            if (presence == null) {
                              return const SizedBox.shrink();
                            }
                            final statusMsg = presence.statusMsg;
                            final lastActiveTimestamp =
                                presence.lastActiveTimestamp;
                            final presenceText =
                                presence.currentlyActive == true
                                ? L10n.of(context).currentlyActive
                                : lastActiveTimestamp != null
                                ? L10n.of(context).lastActiveAgo(
                                    lastActiveTimestamp.localizedTimeShort(
                                      context,
                                    ),
                                  )
                                : null;
                            return SingleChildScrollView(
                              child: Column(
                                spacing: 4,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Avatar(
                                      mxContent: avatar,
                                      name: displayname,
                                      size: Avatar.defaultSize * 2,
                                      onTap: avatar != null
                                          ? () => showDialog(
                                              context: context,
                                              useRootNavigator: false,
                                              builder: (_) =>
                                                  MxcImageViewer(avatar),
                                            )
                                          : null,
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 256,
                                    ),
                                    child: Center(
                                      child: Text(
                                        displayname,
                                        textAlign: TextAlign.center,
                                        textScaler: const TextScaler.linear(
                                          1.67,
                                        ),
                                        style: TextStyle(
                                          shadows: controller.bannerUrl != null
                                              ? [
                                                  Shadow(
                                                    offset: Offset(0.0, 0.0),
                                                    blurRadius: 3,
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? Colors.black
                                                        : Colors.white,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (presenceText != null)
                                    Text(
                                      presenceText,
                                      style: const TextStyle(fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  if (statusMsg != null)
                                    SelectableLinkify(
                                      text: statusMsg,
                                      textScaleFactor: MediaQuery.textScalerOf(
                                        context,
                                      ).scale(1),
                                      textAlign: TextAlign.center,
                                      options: const LinkifyOptions(
                                        humanize: false,
                                      ),
                                      linkStyle: TextStyle(
                                        color: theme.colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                        decorationColor:
                                            theme.colorScheme.primary,
                                      ),
                                      onOpen: (url) => UrlLauncher(
                                        context,
                                        url.url,
                                      ).launchUrl(),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return ConstrainedBox(
                              constraints: constraints,
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 5,
                                children: [
                                  if (client.userID != profile.userId) ...[
                                    _buildActionButton(
                                      context: context,
                                      icon: Icons.chat_bubble_outline,
                                      label: L10n.of(context).chat,
                                      onPressed: () async {
                                        final router = GoRouter.of(context);
                                        final roomIdResult =
                                            await showFutureLoadingDialog(
                                              context: context,
                                              future: () =>
                                                  client.startDirectChat(
                                                    profile.userId,
                                                  ),
                                            );
                                        final roomId = roomIdResult.result;
                                        if (roomId == null) return;
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                        router.go('/rooms/$roomId');
                                      },
                                    ),
                                    if (controller.showCallButton)
                                      _buildActionButton(
                                        context: context,
                                        icon: Icons.call,
                                        label: L10n.of(context).callAction,
                                        onPressed: () {
                                          controller.onCallTap();
                                        },
                                      ),
                                    _buildActionButton(
                                      context: context,
                                      icon: Icons.block,
                                      label: L10n.of(context).ignoreUser,
                                      destructive: true,
                                      onPressed: () async {
                                        final router = GoRouter.of(context);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                        router.go(
                                          '/rooms/settings/security/ignorelist',
                                          extra: profile.userId,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const .symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: .max,
                children: [
                  if (controller.isRpcMedia) ...[
                    Material(
                      clipBehavior: .hardEdge,
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: borderRadius,
                      child: Padding(
                        padding: const .all(16),
                        child: Column(
                          children: [
                            Align(
                              alignment: .centerLeft,
                              child: Text(
                                controller.richPresenceData!.containsKey(
                                      'player',
                                    )
                                    ? L10n.of(context).listeningTo(
                                        controller.richPresenceData!['player'],
                                      )
                                    : L10n.of(context).listeningToSomeTunes,
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: .bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: .max,
                              children: [
                                if (controller.richPresenceData!.containsKey(
                                  'cover_url',
                                )) ...[
                                  Material(
                                    clipBehavior: .antiAlias,
                                    borderRadius: BorderRadius.circular(
                                      AppConfig.borderRadius / 2,
                                    ),
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: MxcImage(
                                      uri: Uri.parse(
                                        controller
                                            .richPresenceData!['cover_url'],
                                      ),
                                      width: 128,
                                      height: 128,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                ],
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: .start,
                                    crossAxisAlignment: .start,
                                    children: [
                                      Align(
                                        alignment: .centerLeft,
                                        child: Text(
                                          controller.richPresenceData!['track'],
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      Align(
                                        alignment: .centerLeft,
                                        child: Text(
                                          controller.richPresenceData!['album'],
                                        ),
                                      ),
                                      Align(
                                        alignment: .centerLeft,
                                        child: Text(
                                          controller
                                              .richPresenceData!['artist'],
                                        ),
                                      ),
                                      if (controller.richPresenceData!
                                          .containsKey('streaming_link')) ...[
                                        const SizedBox(height: 8),
                                        FilledButton.tonalIcon(
                                          onPressed: () {
                                            UrlLauncher(
                                              context,
                                              controller
                                                  .richPresenceData!['streaming_link'],
                                              controller
                                                  .richPresenceData!['player'],
                                            ).launchUrl();
                                          },
                                          label: Text(
                                            controller.richPresenceData?.tryGet(
                                                  'player',
                                                ) ??
                                                L10n.of(
                                                  context,
                                                ).openLinkInBrowser,
                                          ),
                                          icon: const Icon(Icons.open_in_new),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (controller.isRpcActivity) ...[
                    Material(
                      clipBehavior: .hardEdge,
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: borderRadius,
                      child: Padding(
                        padding: const .all(16),
                        child: Column(
                          children: [
                            Align(
                              alignment: .centerLeft,
                              child: Text(
                                L10n.of(context).playing,
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: .bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: .max,
                              children: [
                                if (controller.richPresenceData!.containsKey(
                                  'image',
                                )) ...[
                                  Material(
                                    clipBehavior: .antiAlias,
                                    borderRadius: BorderRadius.circular(
                                      AppConfig.borderRadius / 2,
                                    ),
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: MxcImage(
                                      uri: Uri.parse(
                                        controller.richPresenceData!['image'],
                                      ),
                                      width: 128,
                                      height: 128,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                ],
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: .start,
                                    crossAxisAlignment: .start,
                                    children: [
                                      Align(
                                        alignment: .centerLeft,
                                        child: Text(
                                          controller.richPresenceData!['name'],
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      Align(
                                        alignment: .centerLeft,
                                        child: Text(
                                          controller
                                              .richPresenceData!['details'],
                                        ),
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
                    const SizedBox(height: 8),
                  ],
                  Material(
                    clipBehavior: .hardEdge,
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: borderRadius,
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(
                              Icons.alternate_email,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          trailing: const Icon(Icons.copy),
                          title: Text(profile.userId),
                          subtitle: Text(L10n.of(context).matrixId),
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: profile.userId),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  L10n.of(context).copiedToClipboard,
                                ),
                              ),
                            );
                          },
                        ),
                        if (controller.about != null &&
                            controller.about!.isNotEmpty) ...[
                          const ListDivider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondary,
                              child: Icon(
                                Icons.wysiwyg,
                                color: theme.colorScheme.onSecondary,
                              ),
                            ),
                            title: Linkify(
                              text: controller.about!,
                              textScaleFactor: MediaQuery.textScalerOf(
                                context,
                              ).scale(1),
                              style: const TextStyle(fontSize: 16),
                              options: const LinkifyOptions(humanize: false),
                              linkStyle: TextStyle(
                                color: theme.colorScheme.secondary,
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.secondary,
                              ),
                              onOpen: (link) => UrlLauncher(
                                context,
                                link.url,
                                link.text,
                              ).launchUrl(),
                            ),
                            subtitle: Text(L10n.of(context).aboutUser),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (profile.userId != client.userID &&
                      !controller.isQueryingMutualRooms &&
                      controller.mutualRooms.isNotEmpty)
                    Material(
                      clipBehavior: .hardEdge,
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: borderRadius,
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              L10n.of(context).mutualRooms,
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildMutualChatList(
                            context: context,
                            userId: profile.userId,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
