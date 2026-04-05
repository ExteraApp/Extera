import 'dart:io';

import 'package:extera_next/utils/platform_infos.dart';

String getDownloadsDirectory() {
  if (PlatformInfos.isAndroid) {
    return "/sdcard/Download/Extera";
  } else if (PlatformInfos.isLinux) {
    return "${Platform.environment['HOME']}/Downloads/Extera";
  } else if (PlatformInfos.isWindows) {
    return "${Platform.environment['USERPROFILE']}\\Downloads\\Extera";
  }

  return "";
}
