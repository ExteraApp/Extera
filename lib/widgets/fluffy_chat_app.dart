import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:android_system_font/android_system_font.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:extera_next/config/routes.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/download_manager/download_manager.dart';
import 'package:extera_next/widgets/app_lock.dart';
import 'package:extera_next/widgets/background_audio_player.dart';
import 'package:extera_next/widgets/theme_builder.dart';
import '../config/app_config.dart';
import '../utils/custom_scroll_behaviour.dart';
import 'matrix.dart';

class FluffyChatApp extends StatefulWidget {
  final Widget? testWidget;
  final List<Client> clients;
  final String? pincode;
  final SharedPreferences store;

  const FluffyChatApp({
    super.key,
    this.testWidget,
    required this.clients,
    required this.store,
    this.pincode,
  });

  /// getInitialLink may rereturn the value multiple times if this view is
  /// opened multiple times for example if the user logs out after they logged
  /// in with qr code or magic link.
  static bool gotInitialLink = false;

  // Router must be outside of build method so that hot reload does not reset
  // the current path.
  static final GoRouter router = GoRouter(
    routes: AppRoutes.routes,
    debugLogDiagnostics: true,
  );

  @override
  State<FluffyChatApp> createState() => _FluffyChatAppState();
}

class _FluffyChatAppState extends State<FluffyChatApp> {
  final _androidSystemFontPlugin = AndroidSystemFont();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  static Future<ByteData> _readFileBytes(String path) async {
    final bytes = await File(path).readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String fontFilePath;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      fontFilePath =
          await _androidSystemFontPlugin.getFilePath() ??
          'Unknown font file path';
    } on PlatformException {
      fontFilePath = 'Failed to get font file path.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      final fontLoader = FontLoader('SystemFont');
      fontLoader.addFont(_readFileBytes(fontFilePath));
      fontLoader.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeBuilder(
      builder:
          (
            context,
            themeMode,
            primaryColor,
            schemeVariant,
            pureBlack,
            twemoji,
          ) => MaterialApp.router(
            title: AppConfig.applicationName,
            themeMode: themeMode,
            theme: FluffyThemes.buildTheme(
              context,
              Brightness.light,
              primaryColor,
              schemeVariant,
              pureBlack,
              twemoji,
            ),
            darkTheme: FluffyThemes.buildTheme(
              context,
              Brightness.dark,
              primaryColor,
              schemeVariant,
              pureBlack,
              twemoji,
            ),
            scrollBehavior: CustomScrollBehavior(),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            routerConfig: FluffyChatApp.router,
            builder: (context, child) => AppLockWidget(
              pincode: widget.pincode,
              clients: widget.clients,
              // Need a navigator above the Matrix widget for
              // displaying dialogs
              child: DownloadManager(
                child: BackgroundAudioPlayer(
                  child: Matrix(
                    clients: widget.clients,
                    store: widget.store,
                    child: widget.testWidget ?? child,
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
