import 'dart:async';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/themes.dart';
import 'package:extera_next/pages/archive/archive.dart';
import 'package:extera_next/pages/bootstrap/bootstrap_dialog.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:extera_next/pages/chat_details/chat_details.dart';
import 'package:extera_next/pages/chat_encryption_settings/chat_encryption_settings.dart';
import 'package:extera_next/pages/chat_list/chat_list.dart';
import 'package:extera_next/pages/chat_members/chat_members.dart';
import 'package:extera_next/pages/chat_permissions_settings/chat_permissions_settings.dart';
import 'package:extera_next/pages/chat_privacy/chat_privacy.dart';
import 'package:extera_next/pages/chat_search/chat_search_page.dart';
import 'package:extera_next/pages/chat_thread/thread.dart';
import 'package:extera_next/pages/chat_threads/chat_threads.dart';
import 'package:extera_next/pages/chat_widgets/chat_widgets.dart';
import 'package:extera_next/pages/device_settings/device_settings.dart';
import 'package:extera_next/pages/intro/intro_page.dart';
import 'package:extera_next/pages/invitation_selection/invitation_selection.dart';
import 'package:extera_next/pages/login/login.dart';
import 'package:extera_next/pages/new_group/new_group.dart';
import 'package:extera_next/pages/new_private_chat/new_private_chat.dart';
import 'package:extera_next/pages/notifications/notifications.dart';
import 'package:extera_next/pages/profile/profile.dart';
import 'package:extera_next/pages/settings/settings.dart';
import 'package:extera_next/pages/settings_3pid/settings_3pid.dart';
import 'package:extera_next/pages/settings_chat/settings_chat.dart';
import 'package:extera_next/pages/settings_emotes/settings_emotes.dart';
import 'package:extera_next/pages/settings_features/settings_features.dart';
import 'package:extera_next/pages/settings_homeserver/settings_homeserver.dart';
import 'package:extera_next/pages/settings_ignore_list/settings_ignore_list.dart';
import 'package:extera_next/pages/settings_multiple_emotes/settings_multiple_emotes.dart';
import 'package:extera_next/pages/settings_notifications/settings_notifications.dart';
import 'package:extera_next/pages/settings_password/settings_password.dart';
import 'package:extera_next/pages/settings_ringtone/settings_ringtone.dart';
import 'package:extera_next/pages/settings_security/settings_security.dart';
import 'package:extera_next/pages/settings_style/settings_style.dart';
import 'package:extera_next/pages/sign_in/sign_in_page.dart';
import 'package:extera_next/widgets/config_viewer.dart';
import 'package:extera_next/widgets/layouts/empty_page.dart';
import 'package:extera_next/widgets/layouts/two_column_layout.dart';
import 'package:extera_next/widgets/log_view.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/share_scaffold_dialog.dart';

abstract class AppRoutes {
  static FutureOr<String?> loggedInRedirect(
    BuildContext context,
    GoRouterState state,
  ) =>
      (Matrix.of(context).currentBundle?.isNotEmpty ?? false) &&
          Matrix.of(context).client.isLogged()
      ? '/rooms'
      : null;

  static FutureOr<String?> loggedOutRedirect(
    BuildContext context,
    GoRouterState state,
  ) =>
      (Matrix.of(context).currentBundle?.isNotEmpty ?? false) &&
          Matrix.of(context).client.isLogged()
      ? null
      : '/home';

  AppRoutes();

  static final List<RouteBase> routes = [
    GoRoute(
      path: '/',
      redirect: (context, state) =>
          (Matrix.of(context).currentBundle?.isNotEmpty ?? false) &&
              Matrix.of(context).client.isLogged()
          ? '/rooms'
          : '/home',
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const IntroPage()),
      redirect: loggedInRedirect,
      routes: [
        GoRoute(
          path: 'sign_in',
          pageBuilder: (context, state) =>
              defaultPageBuilder(context, state, SignInPage(signUp: false)),
          redirect: loggedInRedirect,
        ),
        GoRoute(
          path: 'sign_up',
          pageBuilder: (context, state) =>
              defaultPageBuilder(context, state, SignInPage(signUp: true)),
          redirect: loggedInRedirect,
        ),
        GoRoute(
          path: 'login',
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            Login(client: state.extra as Client),
          ),
          redirect: loggedInRedirect,
        ),
      ],
    ),
    GoRoute(
      path: '/logs',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const LogViewer()),
    ),
    GoRoute(
      path: '/configs',
      pageBuilder: (context, state) =>
          defaultPageBuilder(context, state, const ConfigViewer()),
    ),
    GoRoute(
      path: '/backup',
      redirect: loggedOutRedirect,
      pageBuilder: (context, state) => defaultPageBuilder(
        context,
        state,
        BootstrapDialog(wipe: state.uri.queryParameters['wipe'] == 'true'),
      ),
    ),
    ShellRoute(
      // Never use a transition on the shell route. Changing the PageBuilder
      // here based on a MediaQuery causes the child to briefly be rendered
      // twice with the same GlobalKey, blowing up the rendering.
      pageBuilder: (context, state, child) => noTransitionPageBuilder(
        context,
        state,
        FluffyThemes.isColumnMode(context) &&
                state.fullPath?.startsWith('/rooms/settings') == false
            ? TwoColumnLayout(
                mainView: ChatList(
                  activeChat: state.pathParameters['roomid'],
                  displayNavigationRail:
                      state.path?.startsWith('/rooms/settings') != true,
                ),
                sideView: child,
              )
            : child,
      ),
      routes: [
        GoRoute(
          path: '/user',
          redirect: loggedOutRedirect,
          pageBuilder: (context, state) =>
              defaultPageBuilder(context, state, const EmptyPage()),
          routes: [
            GoRoute(
              path: ':user_id',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                ProfilePage(
                  Profile(
                    userId: state.pathParameters['user_id']!,
                    displayName: state.uri.queryParameters['display_name'],
                    avatarUrl:
                        state.uri.queryParameters.containsKey('avatar_uri')
                        ? Uri.parse(state.uri.queryParameters['avatar_uri']!)
                        : null,
                  ),
                  noProfileWarning:
                      state.uri.queryParameters['no_profile_warning'] == 'true',
                ),
              ),
              redirect: loggedOutRedirect,
            ),
          ],
        ),
        GoRoute(
          path: '/rooms',
          redirect: loggedOutRedirect,
          pageBuilder: (context, state) => defaultPageBuilder(
            context,
            state,
            FluffyThemes.isColumnMode(context)
                ? const EmptyPage()
                : ChatList(activeChat: state.pathParameters['roomid']),
          ),
          routes: [
            GoRoute(
              path: '/notifications',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const Notifications()),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'archive',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const Archive()),
              routes: [
                GoRoute(
                  path: ':roomid',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatPage(
                      roomId: state.pathParameters['roomid']!,
                      eventId: state.uri.queryParameters['event'],
                    ),
                  ),
                  redirect: loggedOutRedirect,
                  routes: [
                    GoRoute(
                      path: 'threads',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatThreads(roomId: state.pathParameters['roomid']!),
                      ),
                      routes: [
                        GoRoute(
                          path: ':threadroot',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            ThreadPage(
                              roomId: state.pathParameters['roomid']!,
                              threadRootEventId:
                                  state.pathParameters['threadroot']!,
                              eventId: state.uri.queryParameters['event'],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newprivatechat',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const NewPrivateChat()),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newgroup',
              pageBuilder: (context, state) =>
                  defaultPageBuilder(context, state, const NewGroup()),
              redirect: loggedOutRedirect,
            ),
            GoRoute(
              path: 'newspace',
              pageBuilder: (context, state) => defaultPageBuilder(
                context,
                state,
                const NewGroup(createGroupType: CreateGroupType.space),
              ),
              redirect: loggedOutRedirect,
            ),
            ShellRoute(
              pageBuilder: (context, state, child) => defaultPageBuilder(
                context,
                state,
                FluffyThemes.isColumnMode(context)
                    ? TwoColumnLayout(
                        mainView: Settings(key: state.pageKey),
                        sideView: child,
                      )
                    : child,
              ),
              routes: [
                GoRoute(
                  path: 'settings',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    FluffyThemes.isColumnMode(context)
                        ? const EmptyPage()
                        : const Settings(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'notifications',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsNotifications(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'style',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsStyle(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'devices',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const DevicesSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'chat',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsChat(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'emotes',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            EmotesSettings(
                              roomId: state.pathParameters['roomid'],
                            ),
                          ),
                        ),
                      ],
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'ringtone',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsRingtone(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'features',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsFeatures(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'addaccount',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) =>
                          defaultPageBuilder(context, state, const IntroPage()),
                      routes: [
                        GoRoute(
                          path: 'sign_in',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            SignInPage(signUp: false),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'sign_up',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            SignInPage(signUp: true),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'login',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            Login(client: state.extra as Client),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'homeserver',
                      pageBuilder: (context, state) {
                        return defaultPageBuilder(
                          context,
                          state,
                          const SettingsHomeserver(),
                        );
                      },
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'security',
                      redirect: loggedOutRedirect,
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const SettingsSecurity(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'password',
                          pageBuilder: (context, state) {
                            return defaultPageBuilder(
                              context,
                              state,
                              const SettingsPassword(),
                            );
                          },
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: 'ignorelist',
                          pageBuilder: (context, state) {
                            return defaultPageBuilder(
                              context,
                              state,
                              SettingsIgnoreList(
                                initialUserId: state.extra?.toString(),
                              ),
                            );
                          },
                          redirect: loggedOutRedirect,
                        ),
                        GoRoute(
                          path: '3pid',
                          pageBuilder: (context, state) => defaultPageBuilder(
                            context,
                            state,
                            const Settings3Pid(),
                          ),
                          redirect: loggedOutRedirect,
                        ),
                      ],
                    ),
                  ],
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
            GoRoute(
              path: ':roomid',
              pageBuilder: (context, state) {
                final body = state.uri.queryParameters['body'];
                var shareItems = state.extra is List<ShareItem>
                    ? state.extra as List<ShareItem>
                    : null;
                if (body != null && body.isNotEmpty) {
                  shareItems ??= [];
                  shareItems.add(TextShareItem(body));
                }
                return defaultPageBuilder(
                  context,
                  state,
                  ChatPage(
                    roomId: state.pathParameters['roomid']!,
                    shareItems: shareItems,
                    eventId: state.uri.queryParameters['event'],
                    // showThreadRoots:
                    //     state.uri.queryParameters['threads'] == 'true',
                  ),
                );
              },
              redirect: loggedOutRedirect,
              routes: [
                GoRoute(
                  path: 'threads',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatThreads(roomId: state.pathParameters['roomid']!),
                  ),
                  redirect: loggedOutRedirect,
                  routes: [
                    GoRoute(
                      path: ':threadroot',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ThreadPage(
                          roomId: state.pathParameters['roomid']!,
                          threadRootEventId:
                              state.pathParameters['threadroot']!,
                          eventId: state.uri.queryParameters['event'],
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                  ],
                ),
                GoRoute(
                  path: 'search',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatSearchPage(roomId: state.pathParameters['roomid']!),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'encryption',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    const ChatEncryptionSettings(),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'invite',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    InvitationSelection(
                      roomId: state.pathParameters['roomid']!,
                    ),
                  ),
                  redirect: loggedOutRedirect,
                ),
                GoRoute(
                  path: 'details',
                  pageBuilder: (context, state) => defaultPageBuilder(
                    context,
                    state,
                    ChatDetails(roomId: state.pathParameters['roomid']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'widgets',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatWidgets(roomId: state.pathParameters['roomid']!),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'access',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatAccessSettings(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'members',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatMembersPage(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'permissions',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const ChatPermissionsSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'privacy',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        ChatPrivacy(roomId: state.pathParameters['roomid']!),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'invite',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        InvitationSelection(
                          roomId: state.pathParameters['roomid']!,
                        ),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'multiple_emotes',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        const MultipleEmotesSettings(),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'emotes',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        EmotesSettings(roomId: state.pathParameters['roomid']),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                    GoRoute(
                      path: 'emotes/:state_key',
                      pageBuilder: (context, state) => defaultPageBuilder(
                        context,
                        state,
                        EmotesSettings(roomId: state.pathParameters['roomid']),
                      ),
                      redirect: loggedOutRedirect,
                    ),
                  ],
                  redirect: loggedOutRedirect,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  static Page noTransitionPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => NoTransitionPage(
    key: state.pageKey,
    restorationId: state.pageKey.value,
    child: child,
  );

  static Page defaultPageBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => FluffyThemes.isColumnMode(context)
      ? noTransitionPageBuilder(context, state, child)
      : MaterialPage(
          key: state.pageKey,
          restorationId: state.pageKey.value,
          child: child,
        );
}
