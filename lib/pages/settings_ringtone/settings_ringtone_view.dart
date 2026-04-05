import 'package:flutter/material.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/settings_ringtone/settings_ringtone.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';

class SettingsRingtoneView extends StatelessWidget {
  final SettingsRingtoneController controller;

  const SettingsRingtoneView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).ringtone)),
      body: MaxWidthBody(
        child: Column(
          children: [
            ListTile(
              title: Text(
                L10n.of(context).chooseRingtone,
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: .bold,
                ),
              ),
            ),
            Padding(
              padding: const .symmetric(horizontal: 8),
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                clipBehavior: .hardEdge,
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    if (controller.isSystemRingtoneAvailable)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppSettings.ringtone.value == 'system'
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          foregroundColor:
                              AppSettings.ringtone.value == 'system'
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSecondary,
                          child: const Icon(Icons.music_note_outlined),
                        ),
                        trailing: controller.currentRingtone == 'system'
                            ? const Icon(Icons.check_circle)
                            : null,
                        selected: controller.currentRingtone == 'system',
                        title: Text(L10n.of(context).systemRingtone),
                        onTap: () {
                          controller.setRingtone('system');
                        },
                      ),
                    ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: AppConfig.ringtoneFiles.entries
                          .map(
                            (entry) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppSettings.ringtone.value == entry.key
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.secondary,
                                foregroundColor:
                                    AppSettings.ringtone.value == entry.key
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSecondary,
                                child: const Icon(Icons.music_note_outlined),
                              ),
                              title: Text(entry.key),
                              selected: controller.currentRingtone == entry.key,
                              trailing: controller.currentRingtone == entry.key
                                  ? const Icon(Icons.check_circle)
                                  : null,
                              onTap: () {
                                controller.setRingtone(entry.key);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
