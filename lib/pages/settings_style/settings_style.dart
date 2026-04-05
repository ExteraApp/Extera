import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/account_config.dart';
import 'package:extera_next/utils/adaptive_bottom_sheet.dart';
import 'package:extera_next/utils/file_selector.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import 'package:extera_next/widgets/theme_builder.dart';
import '../../widgets/matrix.dart';
import 'settings_style_view.dart';

class SettingsStyle extends StatefulWidget {
  const SettingsStyle({super.key});

  @override
  SettingsStyleController createState() => SettingsStyleController();
}

class SettingsStyleController extends State<SettingsStyle> {
  void setChatColor(Color? color) async {
    // AppConfig.colorSchemeSeed = color;
    ThemeController.of(context).setPrimaryColor(color);
  }

  void setWallpaper() async {
    final client = Matrix.of(context).client;
    final picked = await selectFiles(context, type: FileType.image);
    final pickedFile = picked.firstOrNull;
    if (pickedFile == null) return;

    await showFutureLoadingDialog(
      context: context,
      future: () async {
        final url = await client.uploadContent(
          await pickedFile.readAsBytes(),
          filename: pickedFile.name,
        );
        await client.updateApplicationAccountConfig(
          ApplicationAccountConfig(wallpaperUrl: url),
        );
      },
    );
  }

  double get wallpaperOpacity =>
      _wallpaperOpacity ??
      Matrix.of(context).client.applicationAccountConfig.wallpaperOpacity ??
      0.5;

  double? _wallpaperOpacity;

  void setSchemeVariant() async {
    final theme = Theme.of(context);
    final paletteNames = {
      DynamicSchemeVariant.tonalSpot: L10n.of(context).palette_tonalSpot,
      DynamicSchemeVariant.fidelity: L10n.of(context).palette_fidelity,
      DynamicSchemeVariant.monochrome: L10n.of(context).palette_monochrome,
      DynamicSchemeVariant.neutral: L10n.of(context).palette_neutral,
      DynamicSchemeVariant.vibrant: L10n.of(context).palette_vibrant,
      DynamicSchemeVariant.expressive: L10n.of(context).palette_expressive,
      DynamicSchemeVariant.content: L10n.of(context).palette_content,
      DynamicSchemeVariant.rainbow: L10n.of(context).palette_rainbow,
      DynamicSchemeVariant.fruitSalad: L10n.of(context).palette_fruitSalad,
    };

    await showAdaptiveBottomSheet(
      context: context,
      builder: (context) {
        return Scaffold(
          appBar: AppBar(title: Text(L10n.of(context).colorPalette)),
          body: Padding(
            padding: const .all(8),
            child: Material(
              color: theme.colorScheme.surfaceContainerHigh,
              clipBehavior: .hardEdge,
              borderRadius: BorderRadius.circular(AppConfig.borderRadius),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                children: [
                  for (final value in DynamicSchemeVariant.values)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.palette_outlined,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(paletteNames[value]!),
                      selected: ThemeController.of(context).variant == value,
                      trailing: ThemeController.of(context).variant == value
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () {
                        ThemeController.of(context).setSchemeVariant(value);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void saveWallpaperOpacity(double opacity) async {
    final client = Matrix.of(context).client;
    final result = await showFutureLoadingDialog(
      context: context,
      future: () => client.updateApplicationAccountConfig(
        ApplicationAccountConfig(wallpaperOpacity: opacity),
      ),
    );
    if (result.isValue) return;

    setState(() {
      _wallpaperOpacity = client.applicationAccountConfig.wallpaperOpacity;
    });
  }

  void updateWallpaperOpacity(double opacity) {
    setState(() {
      _wallpaperOpacity = opacity;
    });
  }

  double get wallpaperBlur =>
      _wallpaperBlur ??
      Matrix.of(context).client.applicationAccountConfig.wallpaperBlur ??
      0.5;
  double? _wallpaperBlur;

  void saveWallpaperBlur(double blur) async {
    final client = Matrix.of(context).client;
    final result = await showFutureLoadingDialog(
      context: context,
      future: () => client.updateApplicationAccountConfig(
        ApplicationAccountConfig(wallpaperBlur: blur),
      ),
    );
    if (result.isValue) return;

    setState(() {
      _wallpaperBlur = client.applicationAccountConfig.wallpaperBlur;
    });
  }

  void updateWallpaperBlur(double blur) {
    setState(() {
      _wallpaperBlur = blur;
    });
  }

  void deleteChatWallpaper() => showFutureLoadingDialog(
    context: context,
    future: () => Matrix.of(context).client.setApplicationAccountConfig(
      const ApplicationAccountConfig(wallpaperUrl: null, wallpaperBlur: null),
    ),
  );

  ThemeMode get currentTheme => ThemeController.of(context).themeMode;
  Color? get currentColor => ThemeController.of(context).primaryColor;

  void switchTheme(ThemeMode? newTheme) {
    if (newTheme == null) return;
    switch (newTheme) {
      case ThemeMode.light:
        ThemeController.of(context).setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.dark:
        ThemeController.of(context).setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.system:
        ThemeController.of(context).setThemeMode(ThemeMode.system);
        break;
    }
    setState(() {});
  }

  void changeFontSizeFactor(double d) {
    AppSettings.fontSizeFactor.setItem(d);
    setState(() {});
  }

  void changeAvatarBorderRadius(double d) {
    AppSettings.avatarBorderRadius.setItem(d);
    setState(() {});
  }

  void changeStickerScale(double d) {
    AppSettings.stickerScale.setItem(d);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => SettingsStyleView(this);
}
