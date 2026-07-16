import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher_string.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/dialer/livekit_incoming_call.dart';
import 'package:extera_next/utils/client_manager.dart';
import 'package:extera_next/utils/init_with_restore.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/uia_request_manager.dart';
import 'package:extera_next/utils/voip_plugin.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:extera_next/widgets/fluffy_chat_app.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import '../config/app_config.dart';
import '../config/app_settings.dart';
import '../pages/key_verification/key_verification_dialog.dart';
import '../utils/account_bundles.dart';
import '../utils/background_push.dart';
import 'local_notifications_extension.dart';

// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Matrix extends StatefulWidget {
  final Widget? child;

  final List<Client> clients;

  final Map<String, String>? queryParameters;

  final SharedPreferences store;

  const Matrix({
    this.child,
    required this.clients,
    required this.store,
    this.queryParameters,
    super.key,
  });

  @override
  MatrixState createState() => MatrixState();

  /// Returns the (nearest) Client instance of your application.
  static MatrixState of(BuildContext context) =>
      Provider.of<MatrixState>(context, listen: false);
}

class MatrixState extends State<Matrix> with WidgetsBindingObserver {
  int _activeClient = -1;
  String? activeBundle;

  SharedPreferences get store => widget.store;

  XFile? loginAvatar;
  String? loginUsername;
  bool? loginRegistrationSupported;

  BackgroundPush? backgroundPush;

  Client get client {
    if (_activeClient < 0 || _activeClient >= widget.clients.length) {
      return currentBundle!.first!;
    }
    return widget.clients[_activeClient];
  }

  VoipPlugin? voipPlugin;

  bool get isMultiAccount => widget.clients.length > 1;

  int getClientIndexByMatrixId(String matrixId) =>
      widget.clients.indexWhere((client) => client.userID == matrixId);

  late String currentClientSecret;
  RequestTokenResponse? currentThreepidCreds;

  void setActiveClient(Client? cl) {
    final i = widget.clients.indexWhere((c) => c == cl);
    if (i != -1) {
      _cachedRootSpaces = null;
      _activeClient = i;
      AppSettings.selectedAccount.setItem(cl!.clientName);
      createVoipPlugin();
    } else {
      Logs().w('Tried to set an unknown client ${cl!.userID} as active');
    }
  }

  List<Client?>? get currentBundle {
    if (!hasComplexBundles) {
      return List.from(widget.clients);
    }
    final bundles = accountBundles;
    if (bundles.containsKey(activeBundle)) {
      return bundles[activeBundle];
    }
    return bundles.values.first;
  }

  Map<String?, List<Client?>> get accountBundles {
    final resBundles = <String?, List<_AccountBundleWithClient>>{};
    for (var i = 0; i < widget.clients.length; i++) {
      final bundles = widget.clients[i].accountBundles;
      for (final bundle in bundles) {
        if (bundle.name == null) {
          continue;
        }
        resBundles[bundle.name] ??= [];
        resBundles[bundle.name]!.add(
          _AccountBundleWithClient(client: widget.clients[i], bundle: bundle),
        );
      }
    }
    for (final b in resBundles.values) {
      b.sort(
        (a, b) => a.bundle!.priority == null
            ? 1
            : b.bundle!.priority == null
            ? -1
            : a.bundle!.priority!.compareTo(b.bundle!.priority!),
      );
    }
    return resBundles.map(
      (k, v) => MapEntry(k, v.map((vv) => vv.client).toList()),
    );
  }

  bool get hasComplexBundles => accountBundles.values.any((v) => v.length > 1);

  Client? _loginClientCandidate;

  Future<Client> getLoginClient() async {
    if (widget.clients.isNotEmpty && !client.isLogged()) {
      return client;
    }
    final candidate = _loginClientCandidate ??=
        await ClientManager.createClient(
            '${AppConfig.applicationName}-${DateTime.now().millisecondsSinceEpoch}',
            store,
          )
          ..onLoginStateChanged.stream
              .where((l) => l == LoginState.loggedIn)
              .first
              .then((_) {
                if (!widget.clients.contains(_loginClientCandidate)) {
                  widget.clients.add(_loginClientCandidate!);
                }
                ClientManager.addClientNameToStore(
                  _loginClientCandidate!.clientName,
                  store,
                );
                _registerSubs(_loginClientCandidate!.clientName);
                _loginClientCandidate = null;
                FluffyChatApp.router.go('/rooms');
              });
    if (widget.clients.isEmpty) widget.clients.add(candidate);
    return candidate;
  }

  Client? getClientByName(String name) =>
      widget.clients.firstWhereOrNull((c) => c.clientName == name);

  final onRoomKeyRequestSub = <String, StreamSubscription>{};
  final onKeyVerificationRequestSub = <String, StreamSubscription>{};
  final onNotification = <String, StreamSubscription>{};
  final onLoginStateChanged = <String, StreamSubscription<LoginState>>{};
  final onUiaRequest = <String, StreamSubscription<UiaRequest>>{};

  /// Subscription map for the LiveKit (MSC4075) incoming-call notification
  /// handler. Keys are client names.
  final onLiveKitRtcNotification = <String, StreamSubscription<SyncUpdate>>{};

  String? _cachedPassword;
  Timer? _cachedPasswordClearTimer;

  String? get cachedPassword => _cachedPassword;

  set cachedPassword(String? p) {
    Logs().d('Password cached');
    _cachedPasswordClearTimer?.cancel();
    _cachedPassword = p;
    _cachedPasswordClearTimer = Timer(const Duration(minutes: 10), () {
      _cachedPassword = null;
      Logs().d('Cached Password cleared');
    });
  }

  bool webHasFocus = true;

  String? get activeRoomId {
    final route = FluffyChatApp.router.routeInformationProvider.value.uri.path;
    if (!route.startsWith('/rooms/')) return null;
    return route.split('/')[2];
  }

  final linuxNotifications = PlatformInfos.isLinux
      ? NotificationsClient()
      : null;
  final Map<String, int> linuxNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initMatrix();
    // if (PlatformInfos.isWeb) {
    //   initConfig().then((_) => initSettings());
    // } else {
    //   initSettings();
    // }
  }

  Future<void> initConfig() async {
    try {
      final configJsonString = utf8.decode(
        (await http.get(Uri.parse('config.json'))).bodyBytes,
      );
      final configJson = json.decode(configJsonString);
      AppConfig.loadFromJson(configJson);
    } on FormatException catch (_) {
      Logs().v('[ConfigLoader] config.json not found');
    } catch (e) {
      Logs().v('[ConfigLoader] config.json not found', e);
    }
  }

  void _registerSubs(String name) {
    final c = getClientByName(name);
    if (c == null) {
      Logs().w(
        'Attempted to register subscriptions for non-existing client $name',
      );
      return;
    }
    onRoomKeyRequestSub[name] ??= c.onRoomKeyRequest.stream.listen((
      RoomKeyRequest request,
    ) async {
      if (widget.clients.any(
        ((cl) =>
            cl.userID == request.requestingDevice.userId &&
            cl.identityKey == request.requestingDevice.curve25519Key),
      )) {
        Logs().i(
          '[Key Request] Request is from one of our own clients, forwarding the key...',
        );
        await request.forwardKey();
      }
    });
    onKeyVerificationRequestSub[name] ??= c.onKeyVerificationRequest.stream
        .listen((KeyVerification request) async {
          var hidPopup = false;
          request.onUpdate = () {
            if (!hidPopup &&
                {
                  KeyVerificationState.done,
                  KeyVerificationState.error,
                }.contains(request.state)) {
              FluffyChatApp.router.pop('dialog');
            }
            hidPopup = true;
          };
          request.onUpdate = null;
          hidPopup = true;
          await KeyVerificationDialog(request: request).show(
            FluffyChatApp.router.routerDelegate.navigatorKey.currentContext ??
                context,
          );
        });
    onLoginStateChanged[name] ??= c.onLoginStateChanged.stream.listen((state) {
      final loggedInWithMultipleClients = widget.clients.length > 1;
      if (state == LoginState.loggedOut) {
        _cancelSubs(c.clientName);
        widget.clients.remove(c);
        ClientManager.removeClientNameFromStore(c.clientName, store);
        InitWithRestoreExtension.deleteSessionBackup(name);
      }
      if (loggedInWithMultipleClients && state != LoginState.loggedIn) {
        ScaffoldMessenger.of(
          FluffyChatApp.router.routerDelegate.navigatorKey.currentContext ??
              context,
        ).showSnackBar(
          SnackBar(content: Text(L10n.of(context).oneClientLoggedOut)),
        );

        if (state != LoginState.loggedIn) {
          FluffyChatApp.router.go('/rooms');
        }
      } else {
        FluffyChatApp.router.go(
          state == LoginState.loggedIn ? '/rooms' : '/home',
        );
      }
    });
    onUiaRequest[name] ??= c.onUiaRequest.stream.listen(uiaRequestHandler);
    if (PlatformInfos.isWeb || PlatformInfos.isLinux) {
      c.onSync.stream.first.then((s) {
        html.Notification.requestPermission();
        onNotification[name] ??= c.onNotification.stream.listen(
          showLocalNotification,
        );
      });
    }

    // LiveKit (Element Call) incoming-call popup: listen for
    // org.matrix.msc4075.rtc.notification events when experimentalLiveKit is on.
    // Ringtone playback reuses VoipPlugin (see livekit_incoming_call.dart).
    LiveKitIncomingCallManager().bind(this);
    LiveKitIncomingCallManager().register(c, onLiveKitRtcNotification, name);
  }

  void _cancelSubs(String name) {
    onRoomKeyRequestSub[name]?.cancel();
    onRoomKeyRequestSub.remove(name);
    onKeyVerificationRequestSub[name]?.cancel();
    onKeyVerificationRequestSub.remove(name);
    onLoginStateChanged[name]?.cancel();
    onLoginStateChanged.remove(name);
    onNotification[name]?.cancel();
    onNotification.remove(name);
    onLiveKitRtcNotification[name]?.cancel();
    onLiveKitRtcNotification.remove(name);
  }

  List<Room>? _cachedRootSpaces;

  List<Room> _computeRootSpaces(Client client) {
    final allSpaces = client.rooms.where((room) => room.isSpace).toList();

    final childSpaceIds = <String>{};
    for (final space in allSpaces) {
      for (final child in space.spaceChildren) {
        final roomId = child.roomId;
        if (roomId != null) {
          childSpaceIds.add(roomId);
        }
      }
    }

    return allSpaces
        .where((space) => !childSpaceIds.contains(space.id))
        .toList();
  }

  // ig it would fit more in ChatListController, but we use rootSpaces in settings view to build navrail
  List<Room> get rootSpaces {
    _cachedRootSpaces ??= _computeRootSpaces(client);
    return _cachedRootSpaces!;
  }

  void initMatrix() {
    for (final c in widget.clients) {
      _registerSubs(c.clientName);
    }

    if (AppSettings.selectedAccount.value.isNotEmpty) {
      final selectedClient = widget.clients.firstWhereOrNull(
        (cl) => cl.clientName == AppSettings.selectedAccount.value,
      );
      if (selectedClient != null) {
        setActiveClient(selectedClient);
      }
    }

    if (PlatformInfos.isMobile) {
      backgroundPush = BackgroundPush(
        this,
        onFcmError: (errorMsg, {Uri? link}) async {
          final result = await showOkCancelAlertDialog(
            context:
                FluffyChatApp
                    .router
                    .routerDelegate
                    .navigatorKey
                    .currentContext ??
                context,
            title: L10n.of(context).pushNotificationsNotAvailable,
            message: errorMsg,
            okLabel: link == null
                ? L10n.of(context).ok
                : L10n.of(context).learnMore,
            cancelLabel: L10n.of(context).doNotShowAgain,
          );
          if (result == OkCancelResult.ok && link != null) {
            launchUrlString(
              link.toString(),
              mode: LaunchMode.externalApplication,
            );
          }
          if (result == OkCancelResult.cancel) {
            AppSettings.showNoGoogle.setItem(true);
          }
        },
      );
    }

    createVoipPlugin();
  }

  void createVoipPlugin() async {
    if (!AppSettings.experimentalVoip.value) {
      voipPlugin = null;
      return;
    }
    voipPlugin = VoipPlugin(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logs().v('AppLifecycleState = $state');
    final foreground =
        state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused;
    final resumedLifecyclePresence = PresenceType.values.firstWhere(
      (x) => x.name == AppSettings.presenceStatus.value,
    );
    for (final client in widget.clients) {
      if (AppSettings.autoMarkUnavailable.value &&
          resumedLifecyclePresence == PresenceType.online) {
        client.syncPresence = state == AppLifecycleState.resumed
            ? resumedLifecyclePresence
            : PresenceType.unavailable;
      }
      if (PlatformInfos.isMobile) {
        client.backgroundSync = foreground;
        client.requestHistoryOnLimitedTimeline = !foreground;
        Logs().v('Set background sync to', foreground);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    for (final s in onRoomKeyRequestSub.values) {
      s.cancel();
    }

    for (final s in onKeyVerificationRequestSub.values) {
      s.cancel();
    }

    for (final s in onLoginStateChanged.values) {
      s.cancel();
    }

    for (final s in onNotification.values) {
      s.cancel();
    }

    for (final s in onUiaRequest.values) {
      s.cancel();
    }

    onRoomKeyRequestSub.clear();
    onKeyVerificationRequestSub.clear();
    onLoginStateChanged.clear();
    onNotification.clear();
    onUiaRequest.clear();

    client.httpClient.close();

    linuxNotifications?.close();
    _cachedPasswordClearTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider(create: (_) => this, child: widget.child);
  }

  Future<void> dehydrateAction(BuildContext context) async {
    final response = await showOkCancelAlertDialog(
      context: context,
      isDestructive: true,
      title: L10n.of(context).dehydrate,
      message: L10n.of(context).dehydrateWarning,
    );
    if (response != OkCancelResult.ok) {
      return;
    }
    final result = await showFutureLoadingDialog(
      context: context,
      future: client.exportDump,
    );
    final export = result.result;
    if (export == null) return;

    final exportBytes = Uint8List.fromList(const Utf8Codec().encode(export));

    final exportFileName =
        'fluffychat-export-${DateFormat(DateFormat.YEAR_MONTH_DAY).format(DateTime.now())}.fluffybackup';

    final file = MatrixFile(bytes: exportBytes, name: exportFileName);
    file.save(context);
  }
}

class _AccountBundleWithClient {
  final Client? client;
  final AccountBundle? bundle;

  _AccountBundleWithClient({this.client, this.bundle});
}
