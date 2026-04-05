/*
 *   Famedly
 *   Copyright (C) 2020, 2021 Famedly GmbH
 *   Copyright (C) 2021 Fluffychat
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_new_badger/flutter_new_badger.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:unifiedpush/unifiedpush.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/main.dart';
import 'package:extera_next/utils/notification_background_handler.dart';
import 'package:extera_next/utils/push_helper.dart';
import 'package:extera_next/widgets/fluffy_chat_app.dart';
import '../config/app_config.dart';
import '../config/setting_keys.dart';
import '../widgets/matrix.dart';
import 'platform_infos.dart';

//<GOOGLE_SERVICES>import 'package:fcm_shared_isolate/fcm_shared_isolate.dart';

class NoTokenException implements Exception {
  String get cause => 'Cannot get firebase token';
}

class BackgroundPush {
  static BackgroundPush? _instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  List<Client> clients;
  MatrixState? matrix;
  String? _fcmToken;
  void Function(String errorMsg, {Uri? link})? onFcmError;
  L10n? l10n;

  Future<void> loadLocale() async {
    final context = matrix?.context;
    l10n ??=
        (context != null ? L10n.of(context) : null) ??
        (await L10n.delegate.load(PlatformDispatcher.instance.locale));
  }

  final pendingTests = <String, Completer<void>>{};
  bool firebaseEnabled = false;

  //<GOOGLE_SERVICES>final firebase = FcmSharedIsolate();

  DateTime? lastReceivedPush;

  bool upAction = false;

  Future<void> initialiseLocalNotifications() async {
    await _flutterLocalNotificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('notifications_icon'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) => notificationTap(
        response,
        clients: clients,
        router: FluffyChatApp.router,
        l10n: l10n,
      ),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  void _init() async {
    //<GOOGLE_SERVICES>firebaseEnabled = true;
    try {
      mainIsolateReceivePort?.listen((message) async {
        try {
          await notificationTap(
            NotificationResponseJson.fromJsonString(message),
            clients: clients,
            router: FluffyChatApp.router,
            l10n: l10n,
          );
        } catch (e, s) {
          Logs().wtf('Main Notification Tap crashed', e, s);
        }
      });
      if (PlatformInfos.isAndroid) {
        final port = ReceivePort();
        IsolateNameServer.removePortNameMapping('background_tab_port');
        IsolateNameServer.registerPortWithName(
          port.sendPort,
          'background_tab_port',
        );
        port.listen((message) async {
          try {
            await notificationTap(
              NotificationResponseJson.fromJsonString(message),
              clients: clients,
              router: FluffyChatApp.router,
              l10n: l10n,
            );
          } catch (e, s) {
            Logs().wtf('Main Notification Tap crashed', e, s);
          }
        });
      }
      await initialiseLocalNotifications();
      Logs().v('Flutter Local Notifications initialized');
      //<GOOGLE_SERVICES>firebase.setListeners(
      //<GOOGLE_SERVICES>  onMessage: (message) => PushHelper.pushHelper(
      //<GOOGLE_SERVICES>    PushNotification.fromJson(
      //<GOOGLE_SERVICES>      Map<String, dynamic>.from(message['data'] ?? message),
      //<GOOGLE_SERVICES>    ),
      //<GOOGLE_SERVICES>    clients: clients,
      //<GOOGLE_SERVICES>    l10n: l10n,
      //<GOOGLE_SERVICES>    activeRoomId: matrix?.activeRoomId,
      //<GOOGLE_SERVICES>    activeclients: clients,
      //<GOOGLE_SERVICES>    flutterLocalNotificationsPlugin: _flutterLocalNotificationsPlugin,
      //<GOOGLE_SERVICES>  ),
      //<GOOGLE_SERVICES>);
      if (Platform.isAndroid) {
        await UnifiedPush.initialize(
          onNewEndpoint: _newUpEndpoint,
          onRegistrationFailed: (_, i) => _upUnregistered(i),
          onUnregistered: _upUnregistered,
          onMessage: _onUpMessage,
        );
      }
    } catch (e, s) {
      Logs().e('Unable to initialize Flutter local notifications', e, s);
    }
  }

  BackgroundPush._(this.clients) {
    _init();
  }

  factory BackgroundPush.clientOnly(Client client) {
    return _instance ??= BackgroundPush._([client]);
  }

  factory BackgroundPush(
    MatrixState matrix, {
    final void Function(String errorMsg, {Uri? link})? onFcmError,
  }) {
    final instance = BackgroundPush.clientOnly(matrix.client);
    instance.matrix = matrix;
    // ignore: prefer_initializing_formals
    instance.onFcmError = onFcmError;
    return instance;
  }

  Future<void> cancelNotification(Client client, String roomId) async {
    Logs().v('Cancel notification for room', roomId);
    await _flutterLocalNotificationsPlugin.cancel(id: roomId.hashCode);

    // Workaround for app icon badge not updating
    if (Platform.isIOS) {
      final unreadCount = client.rooms
          .where((room) => room.isUnreadOrInvited && room.id != roomId)
          .length;
      if (unreadCount == 0) {
        FlutterNewBadger.removeBadge();
      } else {
        FlutterNewBadger.setBadge(unreadCount);
      }
      return;
    }
  }

  Future<void> setupPusher({
    String? gatewayUrl,
    String? token,
    Set<String?>? oldTokens,
    bool useDeviceSpecificAppId = false,
    required Client client,
  }) async {
    if (PlatformInfos.isIOS) {
      //<GOOGLE_SERVICES>await firebase.requestPermission();
    }
    if (PlatformInfos.isAndroid) {
      _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    final clientName = PlatformInfos.clientName;
    oldTokens ??= <String>{};
    final pushers =
        await (client.getPushers().catchError((e) {
          Logs().w('[Push] Unable to request pushers', e);
          return <Pusher>[];
        })) ??
        [];
    var setNewPusher = false;
    // Just the plain app id, we add the .data_message suffix later
    var appId = AppConfig.pushNotificationsAppId;
    // we need the deviceAppId to remove potential legacy UP pusher
    var deviceAppId = '$appId.${client.deviceID}';
    // appId may only be up to 64 chars as per spec
    if (deviceAppId.length > 64) {
      deviceAppId = deviceAppId.substring(0, 64);
    }
    if (!useDeviceSpecificAppId && PlatformInfos.isAndroid) {
      appId += '.data_message';
    }
    final thisAppId = useDeviceSpecificAppId ? deviceAppId : appId;
    if (gatewayUrl != null && token != null) {
      final currentPushers = pushers.where((pusher) => pusher.pushkey == token);
      if (currentPushers.length == 1 &&
          currentPushers.first.kind == 'http' &&
          currentPushers.first.appId == thisAppId &&
          currentPushers.first.appDisplayName == clientName &&
          currentPushers.first.deviceDisplayName == client.deviceName &&
          currentPushers.first.lang == 'en' &&
          currentPushers.first.data.url.toString() == gatewayUrl &&
          currentPushers.first.data.format ==
              AppSettings.pushNotificationsPusherFormat.value &&
          mapEquals(currentPushers.single.data.additionalProperties, {
            "data_message": pusherDataMessageFormat,
          })) {
        Logs().i('[Push] Pusher already set');
      } else {
        Logs().i('Need to set new pusher');
        oldTokens.add(token);
        if (client.isLogged()) {
          setNewPusher = true;
        }
      }
    } else {
      Logs().w('[Push] Missing required push credentials');
    }
    for (final pusher in pushers) {
      if ((token != null &&
              pusher.pushkey != token &&
              deviceAppId == pusher.appId) ||
          oldTokens.contains(pusher.pushkey)) {
        try {
          await client.deletePusher(pusher);
          Logs().i('[Push] Removed legacy pusher for this device');
        } catch (err) {
          Logs().w('[Push] Failed to remove old pusher', err);
        }
      }
    }
    if (setNewPusher) {
      try {
        await client.postPusher(
          Pusher(
            pushkey: token!,
            appId: thisAppId,
            appDisplayName: clientName,
            deviceDisplayName: client.deviceName!,
            lang: 'en',
            data: PusherData(
              url: Uri.parse(gatewayUrl!),
              format: AppSettings.pushNotificationsPusherFormat.value,
              additionalProperties: {"data_message": pusherDataMessageFormat},
            ),
            kind: 'http',
          ),
          append: false,
        );
      } catch (e, s) {
        Logs().e('[Push] Unable to set pushers', e, s);
      }
    }
  }

  final pusherDataMessageFormat = Platform.isAndroid
      ? 'android'
      : Platform.isIOS
      ? 'ios'
      : null;

  static bool _wentToRoomOnStartup = false;

  Future<void> setupPush(List<Client> clients) async {
    Logs().d("SetupPush");
    this.clients = clients;

    {
      // migrate single client push settings to multiclient settings
      final endpoint = AppSettings.unifiedPushEndpoint.value;
      if (endpoint.isNotEmpty) {
        matrix!.store.setString(
          clients.first.clientName + AppSettings.unifiedPushEndpoint.key,
          endpoint,
        );
        matrix!.store.remove(AppSettings.unifiedPushEndpoint.key);
      }

      final registered = AppSettings.unifiedPushRegistered.value;

      matrix!.store.setBool(
        clients.first.clientName + AppSettings.unifiedPushRegistered.key,
        registered,
      );
      matrix!.store.remove(AppSettings.unifiedPushRegistered.key);
    }

    if (!clients.any(
          (c) => c.onLoginStateChanged.value == LoginState.loggedIn,
        ) ||
        !PlatformInfos.isMobile ||
        matrix == null) {
      return;
    }
    // Do not setup unifiedpush if this has been initialized by
    // an unifiedpush action
    if (upAction) {
      return;
    }
    if (!PlatformInfos.isIOS &&
        (await UnifiedPush.getDistributors()).isNotEmpty) {
      await setupUp();
    } else {
      await setupFirebase();
    }

    // ignore: unawaited_futures
    _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails().then((
      details,
    ) {
      if (details == null ||
          !details.didNotificationLaunchApp ||
          _wentToRoomOnStartup) {
        return;
      }
      _wentToRoomOnStartup = true;
      final response = details.notificationResponse;
      if (response != null) {
        notificationTap(
          response,
          clients: clients,
          router: FluffyChatApp.router,
          l10n: l10n,
        );
      }
    });
  }

  Future<void> _noFcmWarning() async {
    if (matrix == null) {
      return;
    }
    if (AppSettings.showNoGoogle.value) {
      return;
    }
    await loadLocale();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PlatformInfos.isAndroid) {
        onFcmError?.call(
          l10n!.noGoogleServicesWarning,
          link: Uri.parse(AppConfig.enablePushTutorial),
        );
        return;
      }
      onFcmError?.call(l10n!.oopsPushError);
    });
  }

  Future<void> setupFirebase() async {
    Logs().v('Setup firebase');
    if (_fcmToken?.isEmpty ?? true) {
      try {
        //<GOOGLE_SERVICES>_fcmToken = await firebase.getToken();
        if (_fcmToken == null) throw ('PushToken is null');
      } catch (e, s) {
        Logs().w('[Push] cannot get token', e, e is String ? null : s);
        await _noFcmWarning();
        return;
      }
    }
    for (final client in clients) {
      if (client.isLogged()) {
        await setupPusher(
          gatewayUrl: AppSettings.pushNotificationsGatewayUrl.value,
          token: _fcmToken,
          client: client,
        );
      }
    }
  }

  Future<void> setupUp() async {
    final distributors = await UnifiedPush.getDistributors();
    if (distributors.isEmpty) {
      Logs().i('[Push] No UnifiedPush distributors found');
      return;
    }

    // Check if a distributor is already saved
    final savedDistributor = await UnifiedPush.getDistributor();
    if (savedDistributor != null) {
      Logs().i('[Push] Using saved UnifiedPush distributor: $savedDistributor');
      for (final client in clients) {
        if (client.isLogged()) {
          await UnifiedPush.register(instance: client.clientName);
        }
      }
      return;
    }

    String selectedDistributor;
    if (distributors.length == 1) {
      selectedDistributor = distributors.first;
    } else {
      // Multiple distributors: show a picker dialog
      final dialogContext =
          FluffyChatApp.router.routerDelegate.navigatorKey.currentContext ??
          matrix!.context;

      if (!dialogContext.mounted) {
        Logs().w('[Push] Context not mounted, cannot show distributor picker');
        // Fallback: use the first distributor
        selectedDistributor = distributors.first;
      } else {
        await loadLocale();
        final picked = await showDialog<String>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: Text(
              l10n?.selectPushDistributor ?? 'Select push distributor',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: distributors
                  .map(
                    (d) => ListTile(
                      title: Text(
                        d.split('.').last[0].toUpperCase() +
                            d.split('.').last.substring(1),
                      ),
                      subtitle: Text(d),
                      onTap: () => Navigator.of(context).pop(d),
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
            ],
          ),
        );

        if (picked != null) {
          selectedDistributor = picked;
        } else {
          // User dismissed the dialog - use the first distributor as fallback
          Logs().i(
            '[Push] User dismissed distributor picker, using first available',
          );
          selectedDistributor = distributors.first;
        }
      }
    }

    Logs().i('[Push] Saving UnifiedPush distributor: $selectedDistributor');
    await UnifiedPush.saveDistributor(selectedDistributor);
    for (final client in clients) {
      if (client.isLogged()) {
        await UnifiedPush.register(instance: client.clientName);
      }
    }
  }

  Future<void> _newUpEndpoint(PushEndpoint newPushEndpoint, String i) async {
    final newEndpoint = newPushEndpoint.url;
    upAction = true;
    if (newEndpoint.isEmpty) {
      await _upUnregistered(i);
      return;
    }
    var endpoint =
        'https://matrix.gateway.unifiedpush.org/_matrix/push/v1/notify';
    try {
      final url = Uri.parse(newEndpoint)
          .replace(path: '/_matrix/push/v1/notify', query: '')
          .toString()
          .split('?')
          .first;
      final res = json.decode(
        utf8.decode((await http.get(Uri.parse(url))).bodyBytes),
      );
      if (res['gateway'] == 'matrix' ||
          (res['unifiedpush'] is Map &&
              res['unifiedpush']['gateway'] == 'matrix')) {
        endpoint = url;
      }
    } catch (e) {
      Logs().i(
        '[Push] No self-hosted unified push gateway present: $newEndpoint',
      );
    }
    Logs().i('[Push] UnifiedPush using endpoint $endpoint');
    final oldTokens = <String?>{};
    try {
      //<GOOGLE_SERVICES>final fcmToken = await firebase.getToken();
      //<GOOGLE_SERVICES>oldTokens.add(fcmToken);
    } catch (_) {}
    final client = clientFromInstance(i, clients) ?? clients.first;
    await setupPusher(
      gatewayUrl: endpoint,
      token: newEndpoint,
      oldTokens: oldTokens,
      useDeviceSpecificAppId: true,
      client: client,
    );
    await matrix?.store.setString(
      client.clientName + AppSettings.unifiedPushEndpoint.key,
      newEndpoint,
    );
    await matrix?.store.setBool(
      client.clientName + AppSettings.unifiedPushRegistered.key,
      true,
    );
  }

  Future<void> _upUnregistered(String i) async {
    upAction = true;
    final client = clientFromInstance(i, clients);
    if (client == null) {
      Logs().w('[Push] Could not find client for instance $i');
      return;
    }
    Logs().i(
      '[Push] Removing UnifiedPush endpoint for ${client.clientName}...',
    );
    final endpointKey = client.clientName + AppSettings.unifiedPushEndpoint.key;
    final registeredKey =
        client.clientName + AppSettings.unifiedPushRegistered.key;
    final oldEndpoint = matrix?.store.getString(endpointKey) ?? '';
    await matrix?.store.setString(endpointKey, '');
    await matrix?.store.setBool(registeredKey, false);
    if (oldEndpoint.isNotEmpty) {
      // remove the old pusher
      await setupPusher(oldTokens: {oldEndpoint}, client: client);
    }
  }

  Future<void> _onUpMessage(PushMessage pushMessage, String i) async {
    Logs().wtf('Push Notification from UP received', pushMessage);
    final message = pushMessage.content;
    upAction = true;
    final data = Map<String, dynamic>.from(
      json.decode(utf8.decode(message))['notification'],
    );
    // UP may strip the devices list
    data['devices'] ??= [];
    await PushHelper.pushHelper(
      PushNotification.fromJson(data),
      clients: clients,
      l10n: l10n,
      activeRoomId: matrix?.activeRoomId,
      activeClient: clientFromInstance(i, clients),
      flutterLocalNotificationsPlugin: _flutterLocalNotificationsPlugin,
      instance: i,
      useNotificationActions:
          false, // Buggy with UP: https://codeberg.org/UnifiedPush/flutter-connector/issues/34
    );
  }
}

Client? clientFromInstance(String? instance, List<Client> clients) {
  for (final c in clients) {
    if (c.clientName == instance) {
      return c;
    }
  }
  return null;
}
