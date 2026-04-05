import 'dart:async';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/pages/settings_ringtone/settings_ringtone_view.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/matrix.dart';

class SettingsRingtone extends StatefulWidget {
  const SettingsRingtone({super.key});

  @override
  State<StatefulWidget> createState() => SettingsRingtoneController();
}

class SettingsRingtoneController extends State<SettingsRingtone> {
  late final SharedPreferences store;
  bool ringtonePlaying = false;

  @override
  void initState() {
    super.initState();
    store = Matrix.of(context).store;
  }

  String get currentRingtone {
    return AppSettings.ringtone.value;
  }

  bool get isSystemRingtoneAvailable => PlatformInfos.isMobile;

  void setRingtone(String ringtone) {
    setState(() {
      AppSettings.ringtone.setItem(ringtone);
      previewRingtone();
    });
  }

  void previewRingtone() {
    final voipPlugin = Matrix.of(context).voipPlugin;
    if (ringtonePlaying) {
      ringtonePlaying = false;
      voipPlugin?.stopRingtone();
      return;
    }
    ringtonePlaying = true;
    voipPlugin?.playRingtone();
    Timer(const Duration(seconds: 15), voipPlugin!.stopRingtone);
  }

  @override
  Widget build(BuildContext context) => SettingsRingtoneView(this);
}
