import 'dart:async';

import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/app_settings.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat_list/chat_list.dart';
import 'package:extera_next/pages/dialer/livekit_call_manager.dart';
import 'package:extera_next/pages/dialer/livekit_call_screen.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/fluffy_chat_app.dart';
import 'package:extera_next/widgets/matrix.dart';

class LiveKitIncomingCallManager {
  static final LiveKitIncomingCallManager _instance =
      LiveKitIncomingCallManager._internal();
  factory LiveKitIncomingCallManager() => _instance;
  LiveKitIncomingCallManager._internal();

  OverlayEntry? _overlayEntry;

  String? _activeRoomId;

  bool _showing = false;

  Timer? _lifetimeTimer;

  MatrixState? _matrix;

  BuildContext? _resolveContext() {
    return ChatList.contextForVoip ??
        FluffyChatApp.router.routerDelegate.navigatorKey.currentContext;
  }

  void bind(MatrixState matrix) => _matrix = matrix;

  void register(
    Client client,
    Map<String, StreamSubscription<SyncUpdate>> subs,
    String name,
  ) {
    if (!AppSettings.experimentalLiveKit.value) return;
    subs[name] ??= client.onSync.stream
        .where((s) => s.rooms?.join != null)
        .listen((s) => _onSync(client, s));
  }

  void _onSync(Client client, SyncUpdate s) {
    final join = s.rooms!.join!;
    for (final entry in join.entries) {
      final roomId = entry.key;
      final events = entry.value.timeline?.events;
      if (events == null || events.isEmpty) continue;
      for (final ev in events) {
        if (ev.type != 'org.matrix.msc4075.rtc.notification') continue;
        if (ev.senderId == client.userID) continue;
        _handleNotification(
          client,
          roomId,
          ev.content,
          ev.senderId,
          ev.originServerTs,
        );
      }
    }
  }

  void _handleNotification(
    Client client,
    String roomId,
    Map<String, Object?> content,
    String senderId,
    DateTime originServerTs,
  ) {
    final lifetimeMs = (content['lifetime'] as num?)?.toInt() ?? 30000;
    final senderTs = (content['sender_ts'] as num?)?.toInt();
    final referenceMs = senderTs ?? originServerTs.millisecondsSinceEpoch;
    final expiresAt = referenceMs + lifetimeMs;
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      Logs().w('[LiveKitIncoming] Ignoring stale RTC notification in $roomId.');
      return;
    }

    if (LiveKitCallManager().isInCall) {
      Logs().w('[LiveKitIncoming] Ignoring notification: already in a call.');
      return;
    }

    if (_showing && _activeRoomId == roomId) return;

    if (_showing) {
      _dismiss();
    }

    final room = client.getRoomById(roomId);
    if (room == null) return;

    _activeRoomId = roomId;
    _showing = true;

    _startRingtone();

    _lifetimeTimer?.cancel();
    _lifetimeTimer = Timer(Duration(milliseconds: lifetimeMs), _dismiss);

    _present(room, senderId);
  }

  void _present(Room room, String senderId) {
    final context = _resolveContext();
    if (context == null) {
      Logs().w('[LiveKitIncoming] No context available to show popup.');
      _dismiss();
      return;
    }

    final client = room.client;

    if (FluffyThemes.isColumnMode(context)) {
      unawaited(
        showDialog(
          context: context,
          useRootNavigator: false,
          barrierDismissible: true,
          builder: (_) => _IncomingCallPopup(
            room: room,
            senderId: senderId,
            client: client,
            onAccept: () => _accept(context, room.id),
            onReject: () => _dismiss(),
          ),
        ).then((_) {
          if (_activeRoomId == room.id) {
            _dismiss();
          }
        }),
      );
    } else {
      final overlay = Overlay.of(context, rootOverlay: true);
      _overlayEntry = OverlayEntry(
        builder: (_) => _IncomingCallPopup(
          room: room,
          senderId: senderId,
          client: client,
          onAccept: () => _accept(context, room.id),
          onReject: () => _dismiss(),
        ),
      );
      overlay.insert(_overlayEntry!);
    }
  }

  void _accept(BuildContext context, String roomId) {
    _stopRingtone();
    _lifetimeTimer?.cancel();
    _lifetimeTimer = null;
    final entry = _overlayEntry;
    _overlayEntry = null;
    entry?.remove();
    _showing = false;
    _activeRoomId = null;
    if (FluffyThemes.isColumnMode(context)) {
      final nav = Navigator.of(context, rootNavigator: false);
      if (nav.canPop()) nav.pop();
    }
    unawaited(openLiveKitCall(context, roomId));
  }

  void _dismiss() {
    _stopRingtone();
    _lifetimeTimer?.cancel();
    _lifetimeTimer = null;
    _showing = false;
    _activeRoomId = null;
    final entry = _overlayEntry;
    _overlayEntry = null;
    entry?.remove();
    final context = _resolveContext();
    if (context != null && FluffyThemes.isColumnMode(context)) {
      final nav = Navigator.of(context, rootNavigator: false);
      if (nav.canPop()) nav.pop();
    }
  }

  void _startRingtone() {
    try {
      _matrix?.voipPlugin?.playRingtone();
    } catch (e) {
      Logs().e('[LiveKitIncoming] playRingtone failed', e);
    }
  }

  void _stopRingtone() {
    try {
      _matrix?.voipPlugin?.stopRingtone();
    } catch (e) {
      Logs().e('[LiveKitIncoming] stopRingtone failed', e);
    }
  }
}

class _IncomingCallPopup extends StatelessWidget {
  final Room room;
  final String senderId;
  final Client client;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingCallPopup({
    required this.room,
    required this.senderId,
    required this.client,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isColumn = FluffyThemes.isColumnMode(context);
    final displayName = room.getLocalizedDisplayname(
      MatrixLocals(L10n.of(context)),
    );

    final body = SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Avatar(
              mxContent: room.avatar,
              name: displayName,
              size: 96,
              client: client,
            ),
            const SizedBox(height: 24),
            Text(
              L10n.of(context).incomingCall,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              displayName,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'lk_incoming_reject',
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  tooltip: L10n.of(context).hangUp,
                  onPressed: onReject,
                  child: const Icon(Icons.call_end),
                ),
                FloatingActionButton(
                  heroTag: 'lk_incoming_accept',
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  tooltip: L10n.of(context).answerCall,
                  onPressed: onAccept,
                  child: const Icon(Icons.phone),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (isColumn) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
            color: theme.colorScheme.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(color: Colors.transparent, child: body),
        ),
      );
    }

    return Material(color: theme.colorScheme.surface, child: body);
  }
}
