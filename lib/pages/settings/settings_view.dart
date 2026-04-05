import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/fluffy_share.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/list_divider.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/mxc_image.dart';
import 'package:extera_next/widgets/navigation_rail.dart';
import '../../widgets/mxc_image_viewer.dart';
import 'settings.dart';

class SettingsView extends StatelessWidget {
  final SettingsController controller;

  const SettingsView(this.controller, {super.key});

  Widget _buildBannerPlaceholder(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppConfig.borderRadius);
    final showChatBackupBanner = controller.showChatBackupBanner;
    final activeRoute = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    return Row(
      children: [
        if (FluffyThemes.isColumnMode(context)) ...[
          SpacesNavigationRail(
            activeSpaceId: null,
            onGoToChats: () => context.go('/rooms'),
            onGoToSpaceId: (spaceId) => context.go('/rooms?spaceId=$spaceId'),
          ),
          Container(color: Theme.of(context).dividerColor, width: 1),
        ],
        Expanded(
          child: Scaffold(
            appBar: FluffyThemes.isColumnMode(context)
                ? null
                : AppBar(
                    title: Text(L10n.of(context).settings),
                    leading: Center(
                      child: BackButton(onPressed: () => context.go('/rooms')),
                    ),
                  ),
            body: ListTileTheme(
              iconColor: theme.colorScheme.onSurface,
              child: Padding(
                padding: const .all(8),
                child: ListView(
                  key: const Key('SettingsListViewContent'),
                  children: <Widget>[
                    FutureBuilder<Profile>(
                      future: controller.profileFuture,
                      builder: (context, snapshot) {
                        final profile = snapshot.data;
                        final avatar = profile?.avatarUrl;
                        final mxid =
                            Matrix.of(context).client.userID ??
                            L10n.of(context).user;
                        final displayname =
                            profile?.displayName ?? mxid.localpart ?? mxid;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            FutureBuilder<String?>(
                              future: controller.bannerFuture,
                              builder: (context, snapshot) {
                                return Positioned.fill(
                                  child: snapshot.hasData
                                      ? MxcImage(
                                          uri: Uri.parse(snapshot.data!),
                                          fit: BoxFit.cover,
                                          isThumbnail: false,
                                          borderRadius: borderRadius,
                                        )
                                      : _buildBannerPlaceholder(context),
                                );
                              },
                            ),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Stack(
                                    children: [
                                      Avatar(
                                        mxContent: avatar,
                                        name: displayname,
                                        size: Avatar.defaultSize * 2.5,
                                        onTap: avatar != null
                                            ? () => showDialog(
                                                context: context,
                                                useRootNavigator: false,
                                                builder: (_) =>
                                                    MxcImageViewer(avatar),
                                              )
                                            : null,
                                      ),
                                      if (profile != null)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: FloatingActionButton.small(
                                            elevation: 2,
                                            onPressed:
                                                controller.setAvatarAction,
                                            heroTag: null,
                                            child: const Icon(
                                              Icons.camera_alt_outlined,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextButton.icon(
                                        onPressed:
                                            controller.setDisplaynameAction,
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.onSurface,
                                          iconColor:
                                              theme.colorScheme.onSurface,
                                        ),
                                        label: Text(
                                          displayname,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 18,
                                            shadows: controller.hasBanner
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
                                      TextButton.icon(
                                        onPressed: () =>
                                            FluffyShare.share(mxid, context),
                                        icon: const Icon(
                                          Icons.copy_outlined,
                                          size: 14,
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.secondary,
                                          iconColor:
                                              theme.colorScheme.secondary,
                                        ),
                                        label: Text(
                                          mxid,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            shadows: controller.hasBanner
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
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: FutureBuilder<String?>(
                                future: controller.bannerFuture,
                                builder: (context, snapshot) {
                                  return PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      if (value == 'set_banner') {
                                        controller.setBannerAction();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'set_banner',
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.image_outlined),
                                            const SizedBox(width: 12),
                                            Text(L10n.of(context).setBanner),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: borderRadius,
                      clipBehavior: .hardEdge,
                      child: FutureBuilder<String?>(
                        future: controller.aboutFuture,
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: Icon(
                                Icons.wysiwyg,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            title: Text(data ?? L10n.of(context).notSet),
                            subtitle: Text(L10n.of(context).aboutUser),
                            trailing: const Icon(Icons.edit),
                            onTap: controller.setAboutAction,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: borderRadius,
                      clipBehavior: .hardEdge,
                      child: Column(
                        children: [
                          FutureBuilder(
                            future: Matrix.of(context).client.getWellknown(),
                            builder: (context, snapshot) {
                              final accountManageUrl = snapshot
                                  .data
                                  ?.additionalProperties
                                  .tryGetMap<String, Object?>(
                                    'org.matrix.msc2965.authentication',
                                  )
                                  ?.tryGet<String>('account');
                              if (accountManageUrl == null) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                children: [
                                  ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.cyanAccent,
                                      child: Icon(
                                        Icons.account_circle_outlined,
                                      ),
                                    ),
                                    title: Text(L10n.of(context).manageAccount),
                                    trailing: const Icon(
                                      Icons.open_in_new_outlined,
                                    ),
                                    onTap: () => launchUrlString(
                                      accountManageUrl,
                                      mode: LaunchMode.inAppBrowserView,
                                    ),
                                  ),
                                  const ListDivider(),
                                ],
                              );
                            },
                          ),
                          if (showChatBackupBanner == null)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.secondary,
                                child: Icon(
                                  Icons.backup_outlined,
                                  color: theme.colorScheme.onSecondary,
                                ),
                              ),
                              title: Text(L10n.of(context).chatBackup),
                              trailing:
                                  const CircularProgressIndicator.adaptive(),
                            )
                          else
                            SwitchListTile.adaptive(
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: controller.showChatBackupBanner == false,
                              secondary: CircleAvatar(
                                backgroundColor: theme.colorScheme.secondary,
                                child: Icon(
                                  Icons.backup_outlined,
                                  color: theme.colorScheme.onSecondary,
                                ),
                              ),
                              title: Text(L10n.of(context).chatBackup),
                              onChanged: controller.firstRunBootstrapAction,
                            ),
                          const ListDivider(),
                          ListTile(
                            title: Text(L10n.of(context).updateCheckTitle),
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.tertiary,
                              child: Icon(
                                Icons.update_outlined,
                                color: theme.colorScheme.onTertiary,
                              ),
                            ),
                            trailing: Switch(
                              value: AppSettings.checkForUpdates.value,
                              onChanged: controller.setCheckForUpdates,
                            ),
                            onTap: () => controller.setCheckForUpdates(
                              !AppSettings.checkForUpdates.value,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: borderRadius,
                      clipBehavior: .hardEdge,
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: Icon(
                                Icons.format_paint_outlined,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            title: Text(L10n.of(context).changeTheme),
                            tileColor:
                                activeRoute.startsWith('/rooms/settings/style')
                                ? theme.colorScheme.surfaceContainerHigh
                                : null,
                            onTap: () => context.go('/rooms/settings/style'),
                          ),
                          const ListDivider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondary,
                              child: Icon(
                                Icons.notifications_outlined,
                                color: theme.colorScheme.onSecondary,
                              ),
                            ),
                            title: Text(L10n.of(context).notifications),
                            tileColor:
                                activeRoute.startsWith(
                                  '/rooms/settings/notifications',
                                )
                                ? theme.colorScheme.surfaceContainerHigh
                                : null,
                            onTap: () =>
                                context.go('/rooms/settings/notifications'),
                          ),
                          const ListDivider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.tertiary,
                              child: Icon(
                                Icons.devices_outlined,
                                color: theme.colorScheme.onTertiary,
                              ),
                            ),
                            title: Text(L10n.of(context).devices),
                            onTap: () => context.go('/rooms/settings/devices'),
                            tileColor:
                                activeRoute.startsWith(
                                  '/rooms/settings/devices',
                                )
                                ? theme.colorScheme.surfaceContainerHigh
                                : null,
                          ),
                          const ListDivider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondary,
                              child: Icon(
                                Icons.forum_outlined,
                                color: theme.colorScheme.onSecondary,
                              ),
                            ),
                            title: Text(L10n.of(context).chat),
                            onTap: () => context.go('/rooms/settings/chat'),
                            tileColor:
                                activeRoute.startsWith('/rooms/settings/chat')
                                ? theme.colorScheme.surfaceContainerHigh
                                : null,
                          ),
                          const ListDivider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: Icon(
                                Icons.toggle_on_outlined,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            title: Text(L10n.of(context).featureSwitches),
                            onTap: () => context.go('/rooms/settings/features'),
                            tileColor:
                                activeRoute.startsWith(
                                  '/rooms/settings/features',
                                )
                                ? theme.colorScheme.surfaceContainerHigh
                                : null,
                          ),
                          const ListDivider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.tertiary,
                              child: Icon(
                                Icons.shield_outlined,
                                color: theme.colorScheme.onTertiary,
                              ),
                            ),
                            title: Text(L10n.of(context).security),
                            onTap: () => context.go('/rooms/settings/security'),
                            tileColor:
                                activeRoute.startsWith(
                                  '/rooms/settings/security',
                                )
                                ? theme.colorScheme.surfaceContainerHigh
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: borderRadius,
                      clipBehavior: .hardEdge,
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: Icon(
                                Icons.dns_outlined,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            title: Text(
                              L10n.of(context).aboutHomeserver(
                                Matrix.of(context).client.userID?.domain ??
                                    'homeserver',
                              ),
                            ),
                            onTap: () =>
                                context.go('/rooms/settings/homeserver'),
                            tileColor:
                                activeRoute.startsWith(
                                  '/rooms/settings/homeserver',
                                )
                                ? theme.colorScheme.surfaceContainerHigh
                                : null,
                          ),
                          const ListDivider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondary,
                              child: Icon(
                                Icons.privacy_tip_outlined,
                                color: theme.colorScheme.onSecondary,
                              ),
                            ),
                            title: Text(L10n.of(context).privacy),
                            onTap: () => launchUrlString(AppConfig.privacyUrl),
                          ),
                          const ListDivider(),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.tertiary,
                              child: Icon(
                                Icons.info_outline,
                                color: theme.colorScheme.onTertiary,
                              ),
                            ),
                            title: Text(L10n.of(context).about),
                            onTap: () => PlatformInfos.showDialog(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: borderRadius,
                      clipBehavior: .hardEdge,
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.error,
                              child: Icon(
                                Icons.logout_outlined,
                                color: theme.colorScheme.onError,
                              ),
                            ),
                            title: Text(L10n.of(context).logout),
                            onTap: controller.logoutAction,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
