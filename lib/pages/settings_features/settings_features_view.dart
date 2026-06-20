import 'package:flutter/material.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';
import 'package:extera_next/widgets/list_divider.dart';
import 'package:extera_next/widgets/settings_switch_list_tile.dart';
import 'settings_features.dart';

class SettingsFeaturesView extends StatelessWidget {
  final SettingsFeaturesController controller;
  const SettingsFeaturesView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppConfig.borderRadius);

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).featureSwitches),
        automaticallyImplyLeading: !FluffyThemes.isColumnMode(context),
        centerTitle: FluffyThemes.isColumnMode(context),
      ),
      body: ListTileTheme(
        iconColor: theme.textTheme.bodyLarge!.color,
        child: MaxWidthBody(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Material(
                  clipBehavior: Clip.hardEdge,
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: borderRadius,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          L10n.of(context).featureSwitches,
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).useLegacyAppBar,
                        setting: AppSettings.useLegacyChatListAppBar,
                      ),
                      const ListDivider(),
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).useLegacyNavBar,
                        setting: AppSettings.useLegacyNavBar,
                      ),
                      const ListDivider(),
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).messageTranslations,
                        setting: AppSettings.messageTranslation,
                      ),
                      const ListDivider(),
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).latexMath,
                        setting: AppSettings.latexMath,
                      ),
                      const ListDivider(),
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).jitsiFeatureFlag,
                        setting: AppSettings.experimentalJitsi,
                      ),
                      const ListDivider(),
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).enableAppBarCenterTitle,
                        setting: AppSettings.enableAppBarCenterTitle,
                      ),
                      const ListDivider(),
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).enablePeopleTab,
                        setting: AppSettings.enablePeopleTab,
                      ),
                      const ListDivider(),
                      SettingsSwitchListTile.adaptive(
                        title: L10n.of(context).enableFloatingAppBar,
                        setting: AppSettings.enableFloatingAppBar,
                      ),
                      if (PlatformInfos.isMobile) ...[
                        const ListDivider(),
                        SettingsSwitchListTile.adaptive(
                          title: L10n.of(context).enableVideoNotes,
                          setting: AppSettings.enableVideoNotes,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Material(
                  color: theme.colorScheme.surfaceContainerHigh,
                  clipBehavior: Clip.hardEdge,
                  borderRadius: borderRadius,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          L10n.of(context).fonts,
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(L10n.of(context).uiFont),
                        trailing: FilledButton.tonalIcon(
                          onPressed: controller.editUIFont,
                          icon: const Icon(Icons.edit),
                          label: Text(L10n.of(context).edit),
                        ),
                      ),
                      const ListDivider(),
                      ListTile(
                        title: Text(L10n.of(context).uiFontFallback),
                        trailing: FilledButton.tonalIcon(
                          onPressed: controller.editUIFallbackFonts,
                          icon: const Icon(Icons.edit),
                          label: Text(L10n.of(context).edit),
                        ),
                      ),
                      const ListDivider(),
                      ListTile(
                        title: Text(L10n.of(context).monospaceFont),
                        trailing: FilledButton.tonalIcon(
                          onPressed: controller.editMonospaceFont,
                          icon: const Icon(Icons.edit),
                          label: Text(L10n.of(context).edit),
                        ),
                      ),
                      const ListDivider(),
                      ListTile(
                        title: Text(L10n.of(context).monospaceFontFallback),
                        trailing: FilledButton.tonalIcon(
                          onPressed: controller.editMonospaceFallbackFonts,
                          icon: const Icon(Icons.edit),
                          label: Text(L10n.of(context).edit),
                        ),
                      ),
                      const ListDivider(),
                      ListTile(
                        title: Text(L10n.of(context).chatFont),
                        trailing: FilledButton.tonalIcon(
                          onPressed: controller.editChatFont,
                          icon: const Icon(Icons.edit),
                          label: Text(L10n.of(context).edit),
                        ),
                      ),
                      const ListDivider(),
                      ListTile(
                        title: Text(L10n.of(context).chatFontFallback),
                        trailing: FilledButton.tonalIcon(
                          onPressed: controller.editChatFallbackFonts,
                          icon: const Icon(Icons.edit),
                          label: Text(L10n.of(context).edit),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
