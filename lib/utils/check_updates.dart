import 'dart:io';

import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/adaptive_bottom_sheet.dart';
import 'package:extera_next/utils/custom_http_client.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/url_launcher.dart';

Future<String> getLatestVersion() async {
  final http = CustomHttpClient.createHTTPClient();
  final response = await http.get(Uri.parse(AppConfig.updateCheckUrl));

  if (response.statusCode > 399)
    throw HttpException(
      "Failed to fetch latest version: ${response.statusCode}",
    );

  final latestVersion = response.body.trim();

  return latestVersion;
}

void checkForUpdates(BuildContext context) async {
  if (!AppSettings.checkForUpdates.value || AppConfig.alreadyCheckedUpdates)
    return;
  Logs().v("Checking updates...");
  try {
    final currentVersion = await PlatformInfos.getVersion();
    final latestVersion = await getLatestVersion();
    Logs().v(
      "Latest version: $latestVersion | Current version: $currentVersion",
    );
    if (latestVersion == currentVersion) return;

    AppConfig.alreadyCheckedUpdates = true;

    await showAdaptiveBottomSheet(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Scaffold(
          appBar: AppBar(title: Text(L10n.of(context).updateAvailableTitle)),
          body: Column(
            mainAxisSize: .min,
            children: [
              Padding(
                padding: const .symmetric(horizontal: 8),
                child: Text(L10n.of(context).updateAvailable(latestVersion)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.list_alt),
                trailing: const Icon(Icons.chevron_right),
                title: Text(L10n.of(context).changelogButton),
                onTap: () {
                  UrlLauncher(context, AppConfig.changelogUrl).launchUrl();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                trailing: const Icon(Icons.chevron_right),
                title: Text(L10n.of(context).downloadUpdateButton),
                onTap: () {
                  UrlLauncher(context, AppConfig.downloadUpdateUrl).launchUrl();
                },
              ),
            ],
          ),
        );
      },
    );
  } catch (e) {
    Logs().e("Failed to check for updates", e);
  }
}
