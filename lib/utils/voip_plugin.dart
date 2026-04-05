import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc_impl;
import 'package:matrix/matrix.dart';
import 'package:webrtc_interface/webrtc_interface.dart' hide Navigator;

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/pages/chat_list/chat_list.dart';
import 'package:extera_next/pages/dialer/dialer.dart';
import 'package:extera_next/utils/platform_infos.dart';
import '../widgets/matrix.dart';

class VoipPlugin with WidgetsBindingObserver implements WebRTCDelegate {
  final MatrixState matrix;
  Client get client => matrix.client;
  VoipPlugin(this.matrix) {
    voip = VoIP(client, this);
    if (!kIsWeb) {
      final wb = WidgetsBinding.instance;
      wb.addObserver(this);
      didChangeAppLifecycleState(wb.lifecycleState);
    }
  }
  bool background = false;
  bool speakerOn = false;
  bool overlayMinimised = false;
  late VoIP voip;
  OverlayEntry? overlayEntry;
  BuildContext get context => matrix.context;

  final ValueNotifier<CallSession?> currentCallNotifier = ValueNotifier(null);
  CallSession? get currentCallSession => currentCallNotifier.value;
  set currentCallSession(CallSession? value) =>
      currentCallNotifier.value = value;

  @override
  void didChangeAppLifecycleState(AppLifecycleState? state) {
    background =
        (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused);
  }

  void addCallingOverlay(String callId, CallSession call) {
    final context = ChatList.contextForVoip!; // web is weird

    if (overlayEntry != null) {
      Logs().e('[VOIP] addCallingOverlay: The call session already exists?');
      overlayEntry!.remove();
    }

    overlayMinimised = false;

    overlayEntry = OverlayEntry(
      builder: (_) => Calling(
        context: context,
        client: client,
        callId: callId,
        call: call,
        startedAt: DateTime.now(),
        onClear: () {
          overlayEntry?.remove();
          overlayEntry = null;
        },
      ),
      canSizeOverlay: true,
    );
    Overlay.of(context).insert(overlayEntry!);
  }

  @override
  MediaDevices get mediaDevices => webrtc_impl.navigator.mediaDevices;

  @override
  bool get isWeb => kIsWeb;

  @override
  Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]) => webrtc_impl.createPeerConnection(configuration, constraints);

  Future<bool> get hasCallingAccount async => false;

  @override
  Future<void> playRingtone() async {
    try {
      if (AppSettings.ringtone.value == 'system') {
        FlutterRingtonePlayer().playRingtone(looping: true);
      } else if (kIsWeb ||
          PlatformInfos.isMobile ||
          PlatformInfos.isMacOS ||
          PlatformInfos.isLinux) {
        final player = callSoundPlayer = AudioPlayer(playerId: 'ringtone');
        player.setReleaseMode(ReleaseMode.loop);
        player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioMode: AndroidAudioMode.ringtone,
              usageType: AndroidUsageType.notificationRingtone,
            ),
          ),
        );
        player.play(
          AssetSource(AppConfig.ringtoneFiles[AppSettings.ringtone.value]!),
        );
      }
    } catch (ex) {
      Logs().e("Failed to play ringtone", ex);
    }
  }

  @override
  Future<void> stopRingtone() async {
    try {
      Logs().w("Stopping ringtone");
      if (AppSettings.ringtone.value == 'system') {
        FlutterRingtonePlayer().stop();
      } else {
        await callSoundPlayer?.stop();
        await callSoundPlayer?.release();
        await callSoundPlayer?.dispose();
        callSoundPlayer = null;
      }
    } catch (ex) {
      Logs().e("Failed to stop ringtone", ex);
    }
  }

  AudioPlayer? callSoundPlayer;

  Future<void> playCallingSound(CallSession call) async {
    if (callSoundPlayer != null) return;
    if (call.direction == CallDirection.kOutgoing) {
      if (!{
        CallState.kInviteSent,
        CallState.kConnecting,
        CallState.kRinging,
      }.contains(call.state)) {
        return;
      }
      Logs().w("Playing kOutgoing call sound");
      final path = 'sounds/${call.state.name}.ogg';
      if (kIsWeb ||
          PlatformInfos.isMobile ||
          PlatformInfos.isMacOS ||
          PlatformInfos.isLinux) {
        final player = callSoundPlayer = AudioPlayer(playerId: 'ringtone');
        player.setReleaseMode(ReleaseMode.loop);
        player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioMode: AndroidAudioMode.inCall,
              usageType: AndroidUsageType.voiceCommunication,
            ),
          ),
        );
        player.play(AssetSource(path));
      } else {
        Logs().w('Playing sound not implemented for this platform!');
      }
    } else if (call.state == CallState.kRinging) {
      Logs().w("Playing ringtone, ${call.direction.name}");
      playRingtone();
    }
  }

  AudioPlayer? sfxPlayer;

  Future<void> playSoundEffect(String name) async {
    try {
      Logs().w("Playing $name call sfx");
      final path = 'sounds/$name.ogg';
      if (kIsWeb ||
          PlatformInfos.isMobile ||
          PlatformInfos.isMacOS ||
          PlatformInfos.isLinux) {
        final player = sfxPlayer = AudioPlayer(playerId: 'sfx');
        player.setReleaseMode(ReleaseMode.release);
        player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioMode: AndroidAudioMode.inCall,
              usageType: AndroidUsageType.voiceCommunication,
            ),
          ),
        );
        player.play(AssetSource(path));
      } else {
        Logs().w('Playing sound not implemented for this platform!');
      }
    } catch (e) {
      Logs().e("Failed to play sound effect", e);
    }
  }

  Future<void> stopCallingSound() async {
    if (callSoundPlayer != null) {
      await callSoundPlayer?.stop();
      await callSoundPlayer?.dispose();
      callSoundPlayer = null;
    }
    if (sfxPlayer != null) {
      await sfxPlayer?.stop();
      await sfxPlayer?.dispose();
      sfxPlayer = null;
    }
    stopRingtone();
  }

  @override
  Future<void> handleNewCall(CallSession call) async {
    if (PlatformInfos.isAndroid) {
      if (call.direction == .kIncoming &&
          call.remoteUserId == call.client.userID) {
        Logs().w(
          "Ignoring a call from ourselves, it's probably a call to someone else from different device.",
        );
        return;
      }
      try {
        final wasForeground = await FlutterForegroundTask.isAppOnForeground;

        await matrix.store.setString(
          'wasForeground',
          wasForeground == true ? 'true' : 'false',
        );
        FlutterForegroundTask.setOnLockScreenVisibility(
          AppSettings.incomingCallsOnLockScreen.value,
        );
        FlutterForegroundTask.wakeUpScreen();
        FlutterForegroundTask.launchApp();
      } catch (e) {
        Logs().e('VOIP foreground failed $e');
      }
      // use fallback flutter call pages for outgoing and video calls.
      if (!call.callHasEnded) {
        currentCallSession = call;
        overlayMinimised = false;
      }
      Logs().w("current call session ${call.callId}");
      playCallingSound(call);
      addCallingOverlay(call.callId, call);
    } else {
      addCallingOverlay(call.callId, call);
    }
  }

  @override
  Future<void> handleCallEnded(CallSession session) async {
    if (session.callHasEnded && session.callId == currentCallSession?.callId) {
      currentCallSession = null;
    }
    stopCallingSound();
    Logs().w("ended call session ${session.callId}");
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
      if (PlatformInfos.isAndroid) {
        FlutterForegroundTask.setOnLockScreenVisibility(false);
        FlutterForegroundTask.stopService();
        final wasForeground = matrix.store.getString('wasForeground');
        wasForeground == 'false' ? FlutterForegroundTask.minimizeApp() : null;
      }
    }
  }

  @override
  Future<void> handleGroupCallEnded(GroupCallSession groupCall) async {
    // TODO: implement handleGroupCallEnded
  }

  @override
  Future<void> handleNewGroupCall(GroupCallSession groupCall) async {
    // TODO: implement handleNewGroupCall
  }

  @override
  // TODO: implement canHandleNewCall
  bool get canHandleNewCall =>
      voip.currentCID == null && voip.currentGroupCID == null;

  @override
  Future<void> handleMissedCall(CallSession session) async {
    // TODO: implement handleMissedCall
  }

  @override
  // TODO: implement keyProvider
  EncryptionKeyProvider? get keyProvider => throw UnimplementedError();

  @override
  Future<void> registerListeners(CallSession session) async {
    // TODO: implement registerListeners
    if (!session.callHasEnded) {
      currentCallSession = session;
      overlayMinimised = false;
    }
    Logs().w("call register listeners ${session.direction.name}");
    // throw UnimplementedError();
  }
}
