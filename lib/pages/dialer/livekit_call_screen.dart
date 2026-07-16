import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:matrix/matrix.dart' show Client, Logs;

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/dialer/dialer.dart';
import 'package:extera_next/pages/dialer/livekit_call_manager.dart';
import 'package:extera_next/pages/dialer/livekit_service.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/call_members_extension.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/matrix.dart';

class LiveKitCallScreen extends StatefulWidget {
  final String roomId;
  final List<String> liveKitServiceUrls;
  final String? callStateKey;
  const LiveKitCallScreen({
    required this.roomId,
    required this.liveKitServiceUrls,
    this.callStateKey,
    super.key,
  });

  @override
  State<LiveKitCallScreen> createState() => _LiveKitCallScreenState();
}

class _LiveKitCallScreenState extends State<LiveKitCallScreen> {
  lk.Room? _room;
  bool _connecting = true;
  String? _error;
  bool _disposed = false;
  Client? _client;
  String _localDisplayName = '';
  Uri? _localAvatar;

  @override
  void initState() {
    super.initState();
    final manager = LiveKitCallManager();
    if (manager.room != null && manager.currentRoomId == widget.roomId) {
      _room = manager.room;
      _client = manager.client;
      _connecting = false;
      _screenShareActive =
          _room?.localParticipant?.videoTrackPublications.any(
            (pub) => pub.isScreenShare,
          ) ??
          false;
      _setupRoomListeners();
      _fetchProfile();
    } else {
      _connect();
    }
  }

  Future<void> _fetchProfile() async {
    final client = Matrix.of(context).client;
    final matrixRoom = client.getRoomById(widget.roomId);
    final profile = matrixRoom?.unsafeGetUserFromMemoryOrFallback(
      client.userID!,
    );
    if (mounted) {
      setState(() {
        _localDisplayName = profile?.displayName ?? client.userID!;
        _localAvatar = profile?.avatarUrl;
      });
    }
  }

  bool _screenShareActive = false;

  Future<void> _stopFgTaskIfNeeded() async {
    if (!PlatformInfos.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> _startFgTaskIfNeeded() async {
    if (!PlatformInfos.isAndroid) return;
    final client = Matrix.of(context).client;
    final room = client.getRoomById(widget.roomId);
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'notification_channel_id',
        channelName: 'Foreground Notification',
        channelDescription: L10n.of(context).foregroundServiceRunning,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );

    await FlutterForegroundTask.startService(
      notificationTitle: L10n.of(context).ongoingElementCall,
      notificationText: L10n.of(context).ongoingElementCallDetail(
        room?.getLocalizedDisplayname() ?? widget.roomId,
      ),
      serviceTypes: [
        ForegroundServiceTypes.mediaProjection,
        ForegroundServiceTypes.microphone,
        ForegroundServiceTypes.camera,
      ],
      notificationButtons: [
        NotificationButton(id: 'mute', text: L10n.of(context).muteMic),
        NotificationButton(
          id: 'hangup',
          text: L10n.of(context).hangUp,
          textColor: Colors.red,
        ),
      ],
      callback: startCallback,
    );

    FlutterForegroundTask.addTaskDataCallback(onDataReceived);
  }

  void onDataReceived(Object data) async {
    final lp = _room?.localParticipant;
    if (lp == null) return;

    if (data == 'mute') {
      await lp.setMicrophoneEnabled(!lp.isMicrophoneEnabled());
    } else if (data == 'hangup') {
      _hangup();
    }
  }

  Future<void> _toggleScreenShare() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;

    if (_screenShareActive) {
      await lp.setScreenShareEnabled(false);
      setState(() => _screenShareActive = false);
      return;
    }

    try {
      if (PlatformInfos.isAndroid) {
        final source = await rtc.mediaDevices.getDisplayMedia({
          'video': true,
          'audio': true,
        });

        await lp.setScreenShareEnabled(
          true,
          // captureScreenAudio: true,
          screenShareCaptureOptions: lk.ScreenShareCaptureOptions(
            // captureScreenAudio: true,
            maxFrameRate: 30,
            sourceId: source.id,
          ),
        );
      } else {
        final sources = await rtc.desktopCapturer.getSources(
          types: [rtc.SourceType.Screen],
        );

        if (sources.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(L10n.of(context).noScreensAvailable)),
            );
          }
          return;
        }

        await lp.setScreenShareEnabled(
          true,
          // captureScreenAudio: true,
          screenShareCaptureOptions: lk.ScreenShareCaptureOptions(
            // captureScreenAudio: true,
            maxFrameRate: 30,
            sourceId: sources.first.id,
          ),
        );
      }
      setState(() => _screenShareActive = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.of(context).screenShareErrorWithMessage(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _connect() async {
    try {
      await _startFgTaskIfNeeded();
      final client = Matrix.of(context).client;
      _client = client;
      final matrixRoom = client.getRoomById(widget.roomId);
      final profile = matrixRoom?.unsafeGetUserFromMemoryOrFallback(
        client.userID!,
      );
      _localDisplayName = profile?.displayName ?? client.userID!;
      _localAvatar = profile?.avatarUrl;
      final openId = await client.requestOpenIdToken(client.userID!, {});
      final deviceId = client.deviceID ?? '';

      await lk.LiveKitClient.initialize();

      LiveKitCredentials? creds;
      lk.Room? room;

      for (final jwtServiceUrl in widget.liveKitServiceUrls) {
        try {
          creds = await LiveKitService.getCredentials(
            openId: openId,
            roomId: widget.roomId,
            deviceId: deviceId,
            jwtServiceUrl: jwtServiceUrl,
          );
          Logs().d('LiveKit OK: $jwtServiceUrl → ${creds.url}');

          room = lk.Room(
            roomOptions: const lk.RoomOptions(
              adaptiveStream: true,
              dynacast: true,
              defaultAudioCaptureOptions: lk.AudioCaptureOptions(
                echoCancellation: true,
                noiseSuppression: true,
                autoGainControl: true,
                highPassFilter: true,
              ),
            ),
          );

          await room.connect(creds.url, creds.jwt);
          Logs().d('LiveKit connected: $jwtServiceUrl');
          break;
        } catch (e) {
          Logs().d('LiveKit FAIL: $jwtServiceUrl → $e');
          try {
            await room?.dispose();
          } catch (_) {}
          room = null;
          creds = null;
        }
      }

      if (room == null) {
        throw Exception(L10n.of(context).allLiveKitUnavailable);
      }

      _room = room;
      LiveKitCallManager().room = room;
      LiveKitCallManager().callStateKey = widget.callStateKey;
      LiveKitCallManager().client = _client;

      _setupRoomListeners();

      Logs().d(
        'DEBUG: connected, remote participants: ${_room!.remoteParticipants.length}',
      );

      await _room!.localParticipant?.setCameraEnabled(
        false,
        cameraCaptureOptions: const lk.CameraCaptureOptions(
          maxFrameRate: 30,
          params: lk.VideoParametersPresets.h720_169,
        ),
      );
      await _room!.localParticipant?.setMicrophoneEnabled(
        false,
        audioCaptureOptions: const lk.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true,
          typingNoiseDetection: true,
        ),
      );

      if (mounted && !_disposed) {
        setState(() => _connecting = false);
      }
    } catch (e) {
      Logs().d('LiveKit connect error: $e');
      if (mounted && !_disposed) {
        setState(() {
          _error = e.toString();
          _connecting = false;
        });
      }
    }
  }

  void _setupRoomListeners() {
    _room!.addListener(_onRoomUpdate);

    _room!.events.on<lk.ParticipantConnectedEvent>((event) {
      Logs().d('DEBUG: participant connected: ${event.participant.identity}');
      if (mounted) setState(() {});
    });
    _room!.events.on<lk.ParticipantDisconnectedEvent>((event) {
      Logs().d(
        'DEBUG: participant disconnected: ${event.participant.identity}',
      );
      if (mounted) setState(() {});
    });
    _room!.events.on<lk.TrackSubscribedEvent>((event) {
      Logs().d(
        'DEBUG: track subscribed: ${event.participant.identity} ${event.track.source}',
      );
      if (mounted) setState(() {});
    });
    _room!.events.on<lk.TrackUnsubscribedEvent>((event) {
      if (mounted) setState(() {});
    });
    _room!.events.on<lk.TrackPublishedEvent>((event) {
      if (mounted) setState(() {});
    });
    _room!.events.on<lk.LocalTrackPublishedEvent>((event) {
      if (mounted) setState(() {});
    });
  }

  void _onRoomUpdate() {
    if (!mounted || _disposed) return;
    if (_room?.connectionState == lk.ConnectionState.disconnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed) _hangup();
      });
      return;
    }
    if (mounted) setState(() {});
  }

  void _hangup() {
    if (_disposed) return;
    _disposed = true;
    final room = _room;
    _room = null;
    final client = _client ?? LiveKitCallManager().client;
    final stateKey = widget.callStateKey ?? LiveKitCallManager().callStateKey;
    LiveKitCallManager().endCall();
    _cleanupCall(room, client, stateKey);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _cleanupCall(
    lk.Room? room,
    Client? client,
    String? stateKey,
  ) async {
    try {
      await room?.localParticipant?.setCameraEnabled(false);
    } catch (_) {}
    try {
      await room?.localParticipant?.setMicrophoneEnabled(false);
    } catch (_) {}
    try {
      await room?.localParticipant?.setScreenShareEnabled(false);
    } catch (_) {}
    try {
      await room?.disconnect();
    } catch (_) {}
    try {
      await room?.dispose();
    } catch (_) {}
    try {
      await _stopFgTaskIfNeeded();
    } catch (_) {}

    try {
      if (client != null && stateKey != null) {
        try {
          await client.setRoomStateWithKey(
            widget.roomId,
            'org.matrix.msc3401.call.member',
            stateKey,
            {},
          );
        } catch (ex) {
          Logs().e("Failed to send call member state event.", ex);
        }
      }
    } catch (e) {
      Logs().d('DEBUG: error removing call member state: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _room?.removeListener(_onRoomUpdate);
    if (PlatformInfos.isAndroid) {
      FlutterForegroundTask.removeTaskDataCallback(onDataReceived);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _connecting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    L10n.of(context).connectingToCall,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      L10n.of(context).errorWithMessage(_error!),
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _hangup,
                      child: Text(L10n.of(context).close),
                    ),
                  ],
                ),
              ),
            )
          : _buildCallUI(),
    );
  }

  Widget _buildCallUI() {
    final theme = Theme.of(context);
    final participants = _room?.remoteParticipants.values.toList() ?? [];

    final screenShares = <lk.RemoteParticipant>[];
    final regularParticipants = <lk.RemoteParticipant>[];
    for (final p in participants) {
      final hasScreenShare = p.videoTrackPublications.any(
        (pub) => pub.isScreenShare && pub.subscribed,
      );
      if (hasScreenShare) {
        screenShares.add(p);
      } else {
        regularParticipants.add(p);
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: screenShares.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 150.0),
                  child: _ScreenShareView(participant: screenShares.first),
                )
              : regularParticipants.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        L10n.of(context).waitingForParticipants,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : regularParticipants.length == 1
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 150),
                  child: _ParticipantView(regularParticipants.first),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 150),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: regularParticipants.length > 4 ? 3 : 2,
                    childAspectRatio: regularParticipants.length > 4
                        ? 1.0
                        : 0.8,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: regularParticipants.length,
                  itemBuilder: (context, index) =>
                      _ParticipantView(regularParticipants[index]),
                ),
        ),
        Positioned(
          right: 16,
          bottom: 130, // Increased bottom margin to prevent intersection
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_screenShareActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _LocalScreenShareView(
                      localParticipant: _room?.localParticipant,
                    ),
                  ),
                _LocalVideoView(
                  localParticipant: _room?.localParticipant,
                  displayName: _localDisplayName,
                  avatar: _localAvatar,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _CallControls(
            room: _room,
            onHangup: _hangup,
            onScreenShare: _toggleScreenShare,
            screenShareActive: _screenShareActive,
          ),
        ),
      ],
    );
  }
}

class _ScreenShareView extends StatefulWidget {
  final lk.RemoteParticipant participant;
  const _ScreenShareView({required this.participant});

  @override
  State<_ScreenShareView> createState() => _ScreenShareViewState();
}

class _ScreenShareViewState extends State<_ScreenShareView> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onChange);
    _startPolling();
  }

  @override
  void didUpdateWidget(_ScreenShareView oldWidget) {
    oldWidget.participant.removeListener(_onChange);
    widget.participant.addListener(_onChange);
    _startPolling();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    widget.participant.removeListener(_onChange);
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    Future.delayed(const Duration(seconds: 5), () {
      _pollTimer?.cancel();
    });
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.participant;
    final screenSharePub = p.videoTrackPublications.firstWhere(
      (pub) => pub.isScreenShare && pub.subscribed,
      orElse: () => p.videoTrackPublications.first,
    );
    final videoTrack = screenSharePub.track;

    return Stack(
      children: [
        if (videoTrack != null)
          Center(child: lk.VideoTrackRenderer(videoTrack, fit: .contain))
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.screen_share,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  L10n.of(context).isScreenSharing(_shortId(p.identity)),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: p.isSpeaking
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onPrimaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _shortId(p.identity),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _shortId(String identity) {
    final at = identity.indexOf(':');
    return at > 0 ? identity.substring(1, at).toLowerCase() : identity;
  }
}

class _ParticipantView extends StatefulWidget {
  final lk.RemoteParticipant participant;
  const _ParticipantView(this.participant);

  @override
  State<_ParticipantView> createState() => _ParticipantViewState();
}

class _ParticipantViewState extends State<_ParticipantView> {
  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onChange);
  }

  @override
  void didUpdateWidget(_ParticipantView oldWidget) {
    oldWidget.participant.removeListener(_onChange);
    widget.participant.addListener(_onChange);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.participant;
    final videoPub = p.videoTrackPublications
        .where((pub) => !pub.isScreenShare && pub.subscribed)
        .firstOrNull;
    final videoTrack = (videoPub != null && !videoPub.muted)
        ? videoPub.track
        : null;
    final speaking = p.isSpeaking;
    final micPub = p.audioTrackPublications.firstOrNull;
    final micMuted = micPub?.muted ?? true;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: speaking ? theme.colorScheme.tertiary : Colors.transparent,
          width: speaking ? 3 : 0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null)
            lk.VideoTrackRenderer(videoTrack, fit: lk.VideoViewFit.contain)
          else
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 64,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                if (micMuted)
                  _statusBadge(Icons.mic_off, theme.colorScheme.error),
                if (!micMuted && speaking)
                  _statusBadge(Icons.mic, theme.colorScheme.tertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _shortId(p.identity),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  String _shortId(String identity) {
    final at = identity.indexOf(':');
    return at > 0 ? identity.substring(1, at).toLowerCase() : identity;
  }
}

class _LocalVideoView extends StatelessWidget {
  final lk.LocalParticipant? localParticipant;
  final String displayName;
  final Uri? avatar;

  const _LocalVideoView({
    this.localParticipant,
    required this.displayName,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lp = localParticipant;
    if (lp == null) return const SizedBox.shrink();
    final videoPub = lp.videoTrackPublications
        .where((pub) => !pub.isScreenShare)
        .firstOrNull;
    final videoTrack = (videoPub != null && !videoPub.muted)
        ? videoPub.track
        : null;
    final speaking = lp.isSpeaking;
    final micPub = lp.audioTrackPublications.firstOrNull;
    final micMuted = micPub?.muted ?? true;

    return Container(
      width: 110,
      height: 150,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: speaking
              ? theme.colorScheme.tertiary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: speaking ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null)
            lk.VideoTrackRenderer(videoTrack, fit: .contain)
          else
            Center(
              child: Avatar(mxContent: avatar, name: displayName, size: 48),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Row(
              children: [
                if (micMuted)
                  _statusBadge(Icons.mic_off, theme.colorScheme.error),
                if (!micMuted && speaking)
                  _statusBadge(Icons.mic, theme.colorScheme.tertiary),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 12),
    );
  }
}

class _LocalScreenShareView extends StatelessWidget {
  final lk.LocalParticipant? localParticipant;
  const _LocalScreenShareView({this.localParticipant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lp = localParticipant;
    if (lp == null) return const SizedBox.shrink();
    final screenSharePub = lp.videoTrackPublications
        .where((pub) => pub.isScreenShare)
        .firstOrNull;
    final screenShareTrack = screenSharePub?.track;
    if (screenShareTrack == null) return const SizedBox.shrink();

    return Container(
      width: 110,
      height: 150,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.tertiary, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          lk.VideoTrackRenderer(screenShareTrack, fit: .contain),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.screen_share,
                    color: theme.colorScheme.tertiary,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    L10n.of(context).screenShare,
                    style: TextStyle(
                      color: theme.colorScheme.tertiary,
                      fontSize: 10,
                    ),
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

class _CallControls extends StatelessWidget {
  final lk.Room? room;
  final VoidCallback onHangup;
  final VoidCallback onScreenShare;
  final bool screenShareActive;
  const _CallControls({
    this.room,
    required this.onHangup,
    required this.onScreenShare,
    this.screenShareActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lp = room?.localParticipant;
    final micOn = _isMicOn(lp);
    final camOn = _isCamOn(lp);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const .all(16),
        child: Container(
          padding: const .symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                onPressed: () {
                  final manager = LiveKitCallManager();
                  lp?.setMicrophoneEnabled(
                    !micOn,
                    audioCaptureOptions: lk.AudioCaptureOptions(
                      deviceId: manager.selectedAudioInput,
                      echoCancellation: manager.echoCancellation,
                      noiseSuppression: manager.noiseSuppression,
                      autoGainControl: manager.autoGainControl,
                      highPassFilter: true,
                      typingNoiseDetection: true,
                    ),
                  );
                },
                backgroundColor: micOn
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: micOn
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.onSurface,
                child: Icon(micOn ? Icons.mic : Icons.mic_off),
              ),
              FloatingActionButton(
                onPressed: () {
                  final manager = LiveKitCallManager();
                  lp?.setCameraEnabled(
                    !camOn,
                    cameraCaptureOptions: lk.CameraCaptureOptions(
                      deviceId: manager.selectedVideoInput,
                      maxFrameRate: 30,
                      params: lk.VideoParametersPresets.h720_169,
                    ),
                  );
                },
                backgroundColor: camOn
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: camOn
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.onSurfaceVariant,
                child: Icon(camOn ? Icons.videocam : Icons.videocam_off),
              ),
              FloatingActionButton(
                onPressed: onHangup,
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
                child: Icon(Icons.call_end),
              ),

              FloatingActionButton(
                onPressed: onScreenShare,
                backgroundColor: screenShareActive
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: screenShareActive
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.onSurfaceVariant,
                child: Icon(
                  screenShareActive
                      ? Icons.screen_share
                      : Icons.screen_share_outlined,
                ),
              ),
              FloatingActionButton(
                onPressed: () => _showSettingsSheet(context, room),
                child: Icon(Icons.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showSettingsSheet(BuildContext context, lk.Room? room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CallSettingsSheet(room: room),
    );
  }

  bool _isMicOn(lk.LocalParticipant? lp) {
    if (lp == null) return false;
    final pub = lp.audioTrackPublications.firstOrNull;
    return pub != null && !pub.muted;
  }

  bool _isCamOn(lk.LocalParticipant? lp) {
    if (lp == null) return false;
    final pub = lp.videoTrackPublications
        .where((p) => !p.isScreenShare)
        .firstOrNull;
    return pub != null && !pub.muted;
  }
}

Future<void> openLiveKitCall(BuildContext context, String roomId) async {
  final manager = LiveKitCallManager();

  // Check if we are already in THIS call. If so, just push the UI, don't send Matrix state events.
  if (manager.isInCall && manager.currentRoomId == roomId) {
    if (context.mounted) {
      final route = MaterialPageRoute(
        builder: (_) => LiveKitCallScreen(
          roomId: roomId,
          liveKitServiceUrls: const [],
          callStateKey: manager.callStateKey,
        ),
      );
      manager.startCall(roomId, route);
      Navigator.of(context).push(route);
    }
    return;
  }

  // If in a DIFFERENT call, we ideally should prompt or end it, but for now we'll just try to let the new call replace it.
  // The old call will disconnect when the user hangs it up, or if LiveKitClient manages one room at a time, it might fail or replace.
  // But to avoid leaking, let's at least clean up the manager.
  if (manager.isInCall && manager.currentRoomId != roomId) {
    try {
      await manager.room?.localParticipant?.setCameraEnabled(false);
      await manager.room?.localParticipant?.setMicrophoneEnabled(false);
      await manager.room?.localParticipant?.setScreenShareEnabled(false);
      await manager.room?.disconnect();
      await manager.room?.dispose();
    } catch (_) {}
    manager.endCall();
  }

  final client = Matrix.of(context).client;
  final room = client.getRoomById(roomId);
  if (room == null) return;

  final callMembers = room.states['org.matrix.msc3401.call.member'];

  final urls = <String>{};

  if (callMembers != null && callMembers.isNotEmpty) {
    for (final entry in callMembers.entries) {
      final content = entry.value.content;
      if (content.isEmpty) continue;
      final fociPreferred = content['foci_preferred'] as List?;
      for (final f in fociPreferred ?? []) {
        final fMap = f as Map?;
        if (fMap?['type'] == 'livekit') {
          final url = fMap!['livekit_service_url'] as String?;
          if (url != null) urls.add(url);
        }
      }
      final focusActive = content['focus_active'] as Map?;
      if (focusActive?['type'] == 'livekit') {
        final url = focusActive!['livekit_service_url'] as String?;
        if (url != null) urls.add(url);
      }
    }
  }

  try {
    final wellKnown = await client.getWellknown();
    final rtcFoci =
        wellKnown.additionalProperties['org.matrix.msc4143.rtc_foci'];
    if (rtcFoci is List) {
      for (final f in rtcFoci) {
        if (f is Map && f['type'] == 'livekit') {
          final url = f['livekit_service_url'] as String?;
          if (url != null) urls.add(url);
        }
      }
    }
    if (urls.isEmpty) {
      final homeserverUrl = wellKnown.mHomeserver.baseUrl.toString().replaceAll(
        RegExp(r'/+$'),
        '',
      );
      urls.add('$homeserverUrl/livekit-jwt-service');
    }
  } catch (_) {}

  if (urls.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).couldNotFindCallServer)),
      );
    }
    return;
  }

  final deviceId = client.deviceID ?? '';
  final userId = client.userID!;
  final stateKey = '_${userId}_${deviceId}_m.call';
  final membershipID = '$userId:$deviceId';
  final memberEventContent = {
    'application': 'm.call',
    'call_id': '',
    'device_id': deviceId,
    'expires': 14400000,
    'foci_preferred': urls
        .map(
          (u) => {
            'type': 'livekit',
            'livekit_service_url': u,
            'livekit_alias': roomId,
          },
        )
        .toList(),
    'focus_active': {'type': 'livekit', 'focus_selection': 'oldest_membership'},
    'm.call.intent': 'video',
    'membershipID': membershipID,
    'scope': 'm.room',
  };

  try {
    final memberEventId = await client.setRoomStateWithKey(
      roomId,
      'org.matrix.msc3401.call.member',
      stateKey,
      Map<String, Object?>.from(memberEventContent),
    );

    if (room.callMembersCount <= 1 &&
        room.canSendEvent("org.matrix.msc4075.rtc.notification")) {
      await room.sendEvent({
        'lifetime': 30000,
        'm.call.intent': 'video',
        'm.mentions': {
          'room': true,
          'user_ids':
              [], // TODO: we probably can invite only selected users to a call
        },
        'm.relates.to': {'event_id': memberEventId, 'rel_type': 'm.reference'},
        'notification_type': 'notification',
        'sender_ts': DateTime.now()
            .millisecondsSinceEpoch, // maybe i can think of a better approach
      }, type: 'org.matrix.msc4075.rtc.notification');
    }
  } catch (e) {
    Logs().d('DEBUG: error sending call member event: $e');
  }

  if (context.mounted) {
    final route = MaterialPageRoute(
      builder: (_) => LiveKitCallScreen(
        roomId: roomId,
        liveKitServiceUrls: urls.toList(),
        callStateKey: stateKey,
      ),
    );
    LiveKitCallManager().startCall(roomId, route);
    Navigator.of(context).push(route);
  }
}

class _CallSettingsSheet extends StatefulWidget {
  final lk.Room? room;
  const _CallSettingsSheet({this.room});

  @override
  State<_CallSettingsSheet> createState() => _CallSettingsSheetState();
}

class _CallSettingsSheetState extends State<_CallSettingsSheet> {
  List<rtc.MediaDeviceInfo> _audioInputs = [];
  List<rtc.MediaDeviceInfo> _audioOutputs = [];
  List<rtc.MediaDeviceInfo> _videoInputs = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final devices = await rtc.navigator.mediaDevices.enumerateDevices();
    setState(() {
      _audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
      _audioOutputs = devices.where((d) => d.kind == 'audiooutput').toList();
      _videoInputs = devices.where((d) => d.kind == 'videoinput').toList();
    });
  }

  Future<void> _switchAudioInput(rtc.MediaDeviceInfo device) async {
    final manager = LiveKitCallManager();
    setState(() => manager.selectedAudioInput = device.deviceId);
    final lp = widget.room?.localParticipant;
    if (lp == null) return;

    final audioTrack = lp.audioTrackPublications.firstOrNull?.track;
    if (audioTrack is lk.LocalAudioTrack) {
      final options = audioTrack.currentOptions;
      await audioTrack.restartTrack(
        options.copyWith(deviceId: device.deviceId),
      );
    }
  }

  Future<void> _switchAudioOutput(rtc.MediaDeviceInfo device) async {
    final manager = LiveKitCallManager();
    setState(() => manager.selectedAudioOutput = device.deviceId);
    await rtc.Helper.selectAudioOutput(device.deviceId);
  }

  Future<void> _switchVideoInput(rtc.MediaDeviceInfo device) async {
    final manager = LiveKitCallManager();
    setState(() => manager.selectedVideoInput = device.deviceId);
    final lp = widget.room?.localParticipant;
    if (lp == null) return;

    final videoTrack = lp.videoTrackPublications
        .where((p) => !p.isScreenShare)
        .firstOrNull
        ?.track;
    if (videoTrack is lk.LocalVideoTrack) {
      await videoTrack.restartTrack(
        lk.CameraCaptureOptions(
          deviceId: device.deviceId,
          maxFrameRate: 30,
          params: lk.VideoParametersPresets.h720_169,
        ),
      );
    }
  }

  Future<void> _updateAudioSettings() async {
    final lp = widget.room?.localParticipant;
    if (lp == null) return;

    final manager = LiveKitCallManager();
    final audioTrack = lp.audioTrackPublications.firstOrNull?.track;
    if (audioTrack is lk.LocalAudioTrack) {
      final options = audioTrack.currentOptions;
      await audioTrack.restartTrack(
        options.copyWith(
          echoCancellation: manager.echoCancellation,
          noiseSuppression: manager.noiseSuppression,
          autoGainControl: manager.autoGainControl,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = LiveKitCallManager();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context).callSettings,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (_audioInputs.isNotEmpty) ...[
              _sectionTitle(L10n.of(context).microphone),
              const SizedBox(height: 8),
              ..._audioInputs.map(
                (d) => _deviceTile(
                  label: d.label.isEmpty
                      ? L10n.of(
                          context,
                        ).microphoneN(_audioInputs.indexOf(d) + 1)
                      : d.label,
                  selected: manager.selectedAudioInput == d.deviceId,
                  onTap: () => _switchAudioInput(d),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_audioOutputs.isNotEmpty) ...[
              _sectionTitle(L10n.of(context).speaker),
              const SizedBox(height: 8),
              ..._audioOutputs.map(
                (d) => _deviceTile(
                  label: d.label.isEmpty
                      ? L10n.of(context).speakerN(_audioOutputs.indexOf(d) + 1)
                      : d.label,
                  selected: manager.selectedAudioOutput == d.deviceId,
                  onTap: () => _switchAudioOutput(d),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_videoInputs.isNotEmpty) ...[
              _sectionTitle(L10n.of(context).camera),
              const SizedBox(height: 8),
              ..._videoInputs.map(
                (d) => _deviceTile(
                  label: d.label.isEmpty
                      ? L10n.of(context).cameraN(_videoInputs.indexOf(d) + 1)
                      : d.label,
                  selected: manager.selectedVideoInput == d.deviceId,
                  onTap: () => _switchVideoInput(d),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _sectionTitle(L10n.of(context).audioProcessing),
            const SizedBox(height: 8),
            _switchTile(
              title: L10n.of(context).echoCancellation,
              value: manager.echoCancellation,
              onChanged: (v) {
                setState(() => manager.echoCancellation = v);
                _updateAudioSettings();
              },
            ),
            _switchTile(
              title: L10n.of(context).noiseSuppression,
              value: manager.noiseSuppression,
              onChanged: (v) {
                setState(() => manager.noiseSuppression = v);
                _updateAudioSettings();
              },
            ),
            _switchTile(
              title: L10n.of(context).autoGainControl,
              value: manager.autoGainControl,
              onChanged: (v) {
                setState(() => manager.autoGainControl = v);
                _updateAudioSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: theme.colorScheme.secondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _deviceTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
      title: Text(label),
      onTap: onTap,
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
