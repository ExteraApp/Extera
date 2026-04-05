import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_shortcuts_new/flutter_shortcuts_new.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/client_download_content_extension.dart';
import 'package:extera_next/utils/client_manager.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:extera_next/utils/notification_background_handler.dart';
import 'package:extera_next/utils/platform_infos.dart';

const notificationAvatarDimension = 128;

class PushHelper {
  final PushNotification notification;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  final bool useNotificationActions;
  late Client client;
  late Event event;
  late bool isBackgroundMessage;
  L10n? l10n;

  PushHelper._(
    this.notification,
    this.flutterLocalNotificationsPlugin, {
    this.useNotificationActions = true,
  });

  static Future<void> pushHelper(
    PushNotification notification, {
    List<Client>? clients,
    L10n? l10n,
    String? activeRoomId,
    Client? activeClient,
    required FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    String? instance,
    bool useNotificationActions = true,
  }) async {
    final handler = await _newPushHandler(
      notification,
      clients: clients,
      l10n: l10n,
      activeRoomId: activeRoomId,
      activeClient: activeClient,
      flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin,
      instance: instance,
      useNotificationActions: useNotificationActions,
    );
    await handler?._showNotification();
  }

  static FutureOr<PushHelper?> _newPushHandler(
    PushNotification notification, {
    List<Client>? clients,
    L10n? l10n,
    String? activeRoomId,
    Client? activeClient,
    required FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    String? instance,
    bool useNotificationActions = true,
  }) async {
    final helper = PushHelper._(
      notification,
      flutterLocalNotificationsPlugin,
      useNotificationActions: useNotificationActions,
    );
    helper.l10n = l10n;

    try {
      helper.isBackgroundMessage = clients == null;
      Logs().v(
        'Push helper has been started (background=${helper.isBackgroundMessage}).',
        notification.toJson(),
      );

      clients ??= await ClientManager.getClients(
        initialize: false,
        store: await AppSettings.init(),
      );

      final client = _clientFromInstance(instance, clients);
      if (client == null) {
        Logs().e('No client could be found for instance $instance');
        return null;
      }
      helper.client = client;

      // Deduplicate: if multiple clients are in the same room, only the first
      // client in the list that has this room should show the notification.
      // This prevents duplicate push notifications when 2+ accounts share a room.
      if (notification.roomId != null && clients.isNotEmpty) {
        final firstClientInRoom = clients.firstWhereOrNull(
          (c) => c.rooms.any((r) => r.id == notification.roomId),
        );
        if (firstClientInRoom != null && firstClientInRoom != client) {
          Logs().v(
            'Another client (${firstClientInRoom.clientName}) already handles '
            'notifications for room ${notification.roomId}. Skipping for ${client.clientName}.',
          );
          return null;
        }
      }

      if (_isInForeground(notification, activeRoomId, activeClient, client)) {
        Logs().v('Room is in foreground. Stop push helper here.');
        return null;
      }

      final event = await client.getEventByPushNotification(
        notification,
        storeInDatabase: helper.isBackgroundMessage,
      );

      if (event == null) {
        Logs().v('Notification is a clearing indicator.');
        if (notification.counts?.unread == null ||
            notification.counts?.unread == 0) {
          await flutterLocalNotificationsPlugin.cancelAll();
        } else {
          // Make sure client is fully loaded and synced before dismiss notifications:
          await client.roomsLoading;
          await client.oneShotSync();
          final activeNotifications = await flutterLocalNotificationsPlugin
              .getActiveNotifications();
          for (final activeNotification in activeNotifications) {
            final room = client.rooms.singleWhereOrNull(
              (room) => room.id.hashCode == activeNotification.id,
            );
            if (room == null || !room.isUnreadOrInvited) {
              flutterLocalNotificationsPlugin.cancel(
                id: activeNotification.id!,
              );
            }
          }
        }
        return null;
      }
      helper.event = event;

      Logs().v('Push helper got notification event of type ${event.type}.');
      return helper;
    } catch (e, s) {
      await helper._crashHandler(e, s);
      rethrow;
    }
  }

  /// Selects the correct client from the list based on the instance string.
  /// Falls back to the first client if no instance is provided.
  static Client? _clientFromInstance(String? instance, List<Client> clients) {
    if (clients.isEmpty) return null;
    if (instance == null) return clients.first;
    return clients.firstWhereOrNull(
          (client) => client.clientName == instance,
        ) ??
        clients.first;
  }

  Future<void> _crashHandler(Object e, StackTrace s) async {
    Logs().e('Push Helper has crashed!', e, s);

    l10n ??= await lookupL10n(PlatformDispatcher.instance.locale);
    flutterLocalNotificationsPlugin.show(
      id: notification.roomId?.hashCode ?? 0,
      title: l10n!.newMessageInFluffyChat,
      body: l10n!.openAppToReadMessages,
      notificationDetails: NotificationDetails(
        iOS: const DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          AppConfig.pushNotificationsChannelId,
          l10n!.incomingMessages,
          number: notification.counts?.unread,
          ticker: l10n!.unreadChatsInApp(
            AppConfig.applicationName,
            (notification.counts?.unread ?? 0).toString(),
          ),
          importance: Importance.high,
          priority: Priority.max,
          shortcutId: notification.roomId,
        ),
      ),
    );
  }

  Future<void> _showNotification() async {
    try {
      if (event.type.startsWith('m.call')) {
        // make sure bg sync is on (needed to update hold, unhold events)
        // prevent over write from app life cycle change
        client.backgroundSync = true;
      }

      if (event.type == EventTypes.CallHangup) {
        client.backgroundSync = false;
      }

      if (event.type.startsWith('m.call') &&
          event.type != EventTypes.CallInvite) {
        Logs().v('Push message is a m.call but not invite. Do not display.');
        return;
      }

      if ((event.type.startsWith('m.call') &&
              event.type != EventTypes.CallInvite) ||
          event.type == 'org.matrix.call.sdp_stream_metadata_changed') {
        Logs().v('Push message was for a call, but not call invite.');
        return;
      }

      l10n ??= await L10n.delegate.load(PlatformDispatcher.instance.locale);
      final matrixLocals = MatrixLocals(l10n!);

      // Calculate the body
      final body = event.type == EventTypes.Encrypted
          ? l10n!.newMessageInFluffyChat
          : await event.calcLocalizedBody(
              matrixLocals,
              plaintextBody: true,
              withSenderNamePrefix: false,
              hideReply: true,
              hideEdit: true,
              removeMarkdown: true,
            );

      final title = event.room.getLocalizedDisplayname(matrixLocals);
      final roomName = event.room.getLocalizedDisplayname(matrixLocals);

      final notificationGroupId = event.room.isDirectChat
          ? 'directChats'
          : 'groupChats';
      final groupName = event.room.isDirectChat
          ? l10n!.directChats
          : l10n!.groups;

      final messageRooms = AndroidNotificationChannelGroup(
        notificationGroupId,
        groupName,
      );
      final roomsChannel = AndroidNotificationChannel(
        event.room.id,
        roomName,
        groupId: notificationGroupId,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannelGroup(messageRooms);
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(roomsChannel);

      final platformChannelSpecifics = await _getPlatformChannelSpecifics(
        notification.roomId?.hashCode ?? 0,
        body,
        title,
        roomName,
      );

      await flutterLocalNotificationsPlugin.show(
        id: notification.roomId?.hashCode ?? 0,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: NotificationPushPayload(
          client.clientName,
          event.room.id,
          event.eventId,
        ).toString(),
      );
      Logs().v('Push helper has been completed!');
    } catch (e, s) {
      await _crashHandler(e, s);
      rethrow;
    }
  }

  Future<NotificationDetails> _getPlatformChannelSpecifics(
    int notificationId,
    String notificationBody,
    String notificationTitle,
    String roomName,
  ) async {
    // The person object for the android message style notification
    final avatar = event.room.avatar;
    final senderAvatar = event.room.isDirectChat
        ? avatar
        : event.senderFromMemoryOrFallback.avatarUrl;

    final roomAvatarFile = await _getAvatarFile(client, avatar);
    final senderAvatarFile = event.room.isDirectChat
        ? roomAvatarFile
        : await _getAvatarFile(client, senderAvatar);

    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();

    // Show notification
    final newMessage = Message(
      notificationBody,
      event.originServerTs,
      Person(
        bot: event.messageType == MessageTypes.Notice,
        key: event.senderId,
        name: senderName,
        icon: senderAvatarFile == null
            ? null
            : ByteArrayAndroidIcon(senderAvatarFile),
      ),
    );

    final messagingStyleInformation = PlatformInfos.isAndroid
        ? await AndroidFlutterLocalNotificationsPlugin()
              .getActiveNotificationMessagingStyle(id: notificationId)
        : null;
    messagingStyleInformation?.messages?.add(newMessage);

    if (PlatformInfos.isAndroid && messagingStyleInformation == null) {
      await _setShortcut(notificationTitle, roomAvatarFile);
    }

    final matrixLocals = MatrixLocals(l10n!);

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      AppConfig.pushNotificationsChannelId,
      l10n!.incomingMessages,
      number: notification.counts?.unread,
      subText: client.clientName,
      category: AndroidNotificationCategory.message,
      shortcutId: event.room.id,
      styleInformation:
          messagingStyleInformation ??
          MessagingStyleInformation(
            Person(
              name: senderName,
              icon: roomAvatarFile == null
                  ? null
                  : ByteArrayAndroidIcon(roomAvatarFile),
              key: event.roomId,
              important: event.room.isFavourite,
            ),
            conversationTitle: event.room.isDirectChat ? null : roomName,
            groupConversation: !event.room.isDirectChat,
            messages: [newMessage],
          ),
      ticker: event.calcLocalizedBodyFallback(
        matrixLocals,
        plaintextBody: true,
        withSenderNamePrefix: !event.room.isDirectChat,
        hideReply: true,
        hideEdit: true,
        removeMarkdown: true,
      ),
      importance: Importance.high,
      priority: Priority.max,
      groupKey: event.room.spaceParents.firstOrNull?.roomId ?? 'rooms',
      actions: event.type == EventTypes.RoomMember || !useNotificationActions
          ? null
          : <AndroidNotificationAction>[
              AndroidNotificationAction(
                FluffyChatNotificationActions.reply.name,
                l10n!.reply,
                inputs: [
                  AndroidNotificationActionInput(label: l10n!.writeAMessage),
                ],
                cancelNotification: false,
                allowGeneratedReplies: true,
                semanticAction: SemanticAction.reply,
              ),
              AndroidNotificationAction(
                FluffyChatNotificationActions.markAsRead.name,
                l10n!.markAsRead,
                semanticAction: SemanticAction.markAsRead,
              ),
            ],
    );
    const iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    return NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
  }

  /// Creates a shortcut for Android platform but does not block displaying the
  /// notification. This is optional but provides a nicer view of the
  /// notification popup.
  Future<void> _setShortcut(String title, Uint8List? avatarFile) async {
    final flutterShortcuts = FlutterShortcuts();
    await flutterShortcuts.initialize(debug: !kReleaseMode);
    await flutterShortcuts.pushShortcutItem(
      shortcut: ShortcutItem(
        id: event.room.id,
        action: AppConfig.inviteLinkPrefix + event.room.id,
        shortLabel: title,
        conversationShortcut: true,
        icon: avatarFile == null ? null : base64Encode(avatarFile),
        shortcutIconAsset: avatarFile == null
            ? ShortcutIconAsset.androidAsset
            : ShortcutIconAsset.memoryAsset,
        isImportant: event.room.isFavourite,
      ),
    );
  }

  static Future<Uint8List?> _getAvatarFile(Client client, Uri? avatar) async {
    try {
      return avatar == null
          ? null
          : await client
                .downloadMxcCached(
                  avatar,
                  thumbnailMethod: ThumbnailMethod.crop,
                  width: notificationAvatarDimension,
                  height: notificationAvatarDimension,
                  animated: false,
                  isThumbnail: true,
                  rounded: true,
                )
                .timeout(const Duration(seconds: 3));
    } catch (e, s) {
      Logs().e('Unable to get avatar picture', e, s);
      return null;
    }
  }

  static bool _isInForeground(
    PushNotification notification,
    String? activeRoomId,
    Client? activeClient,
    Client notifiedClient,
  ) {
    return notification.roomId != null &&
        activeRoomId == notification.roomId &&
        activeClient == notifiedClient &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }
}

class NotificationPushPayload {
  final String? clientName, roomId, eventId;

  NotificationPushPayload(this.clientName, this.roomId, this.eventId);

  factory NotificationPushPayload.fromString(String payload) {
    final parts = payload.split('|');
    if (parts.length != 3) {
      return NotificationPushPayload(null, null, null);
    }
    return NotificationPushPayload(parts[0], parts[1], parts[2]);
  }

  @override
  String toString() => '$clientName|$roomId|$eventId';
}
