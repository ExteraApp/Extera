import 'dart:async';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/file_selector.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_modal_action_popup.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_text_input_dialog.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import '../../widgets/matrix.dart';
import 'settings_view.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  SettingsController createState() => SettingsController();
}

class SettingsController extends State<Settings> {
  Future<String?>? aboutFuture;
  bool isQueryingAbout = false;

  // Uri? bannerUrl;
  Future<String?>? bannerFuture;
  bool isQueryingBanner = false;
  bool hasBanner = false;

  Future<String?> _getAbout() async {
    final client = Matrix.of(context).client;
    try {
      final aboutResponse = await client.getProfileField(
        client.userID!,
        AppConfig.aboutProfileField,
      );
      if (aboutResponse.containsKey(AppConfig.aboutProfileField) &&
          aboutResponse[AppConfig.aboutProfileField] is String &&
          aboutResponse[AppConfig.aboutProfileField].toString().length <= 256) {
        return aboutResponse[AppConfig.aboutProfileField].toString();
      }
    } catch (ex) {
      Logs().e("Failed to query About field", ex);
    }
    return null;
  }

  Future<String?> _getBanner() async {
    final client = Matrix.of(context).client;
    try {
      final bannerResponse = await client.getProfileField(
        client.userID!,
        AppConfig.bannerProfileField,
      );
      if (bannerResponse.containsKey((AppConfig.bannerProfileField)) &&
          bannerResponse[AppConfig.bannerProfileField] is String &&
          bannerResponse[AppConfig.bannerProfileField].toString().startsWith(
            'mxc://',
          )) {
        hasBanner = true;
        return bannerResponse.tryGet<String>(AppConfig.bannerProfileField);
      }
    } catch (ex) {
      Logs().e("Failed to query banner field", ex);
    }
    hasBanner = false;
    return null;
  }
  // bool aboutUpdated = false;

  Future<Profile>? profileFuture;

  void updateProfile() => setState(() {
    // profileUpdated = true;
    profileFuture = null;
  });

  void updateAbout() => setState(() {
    // aboutUpdated = true;
    aboutFuture = null;
  });

  void updateBanner() => setState(() {
    bannerFuture = null;
  });

  void setAboutAction() async {
    final about = await aboutFuture;
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).editAbout,
      message: L10n.of(context).editAboutDescription,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      initialText: about ?? "",
      hintText: L10n.of(context).aboutExample,
      maxLength: 256,
      maxLines: 1,
    );
    if (input == null) return;
    final matrix = Matrix.of(context);
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => matrix.client.setProfileField(
        matrix.client.userID!,
        'xyz.extera.about',
        {'xyz.extera.about': input},
      ),
    );
    if (success.error == null) {
      updateAbout();
    }
  }

  void setCheckForUpdates(bool newValue) {
    AppSettings.checkForUpdates.setItem(newValue);
    setState(() {});
  }

  void setDisplaynameAction() async {
    final profile = await profileFuture;
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).editDisplayname,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      initialText:
          profile?.displayName ?? Matrix.of(context).client.userID!.localpart,
    );
    if (input == null) return;
    final matrix = Matrix.of(context);
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => matrix.client.setProfileField(
        matrix.client.userID!,
        'displayname',
        {'displayname': input},
      ),
    );
    if (success.error == null) {
      updateProfile();
    }
  }

  void logoutAction() async {
    final noBackup = showChatBackupBanner == true;
    if (await showOkCancelAlertDialog(
          useRootNavigator: false,
          context: context,
          title: L10n.of(context).areYouSureYouWantToLogout,
          message: L10n.of(context).noBackupWarning,
          isDestructive: noBackup,
          okLabel: L10n.of(context).logout,
          cancelLabel: L10n.of(context).cancel,
        ) !=
        OkCancelResult.ok) {
      return;
    }
    final matrix = Matrix.of(context);
    await showFutureLoadingDialog(
      context: context,
      future: () => matrix.client.logout(),
    );
  }

  void setAvatarAction() async {
    final profile = await profileFuture;
    final actions = [
      if (PlatformInfos.isMobile)
        AdaptiveModalAction(
          value: AvatarAction.camera,
          label: L10n.of(context).openCamera,
          isDefaultAction: true,
          icon: const Icon(Icons.camera_alt_outlined),
        ),
      AdaptiveModalAction(
        value: AvatarAction.file,
        label: L10n.of(context).openGallery,
        icon: const Icon(Icons.photo_outlined),
      ),
      if (profile?.avatarUrl != null)
        AdaptiveModalAction(
          value: AvatarAction.remove,
          label: L10n.of(context).removeYourAvatar,
          isDestructive: true,
          icon: const Icon(Icons.delete_outlined),
        ),
    ];
    final action = actions.length == 1
        ? actions.single.value
        : await showModalActionPopup<AvatarAction>(
            context: context,
            title: L10n.of(context).changeYourAvatar,
            cancelLabel: L10n.of(context).cancel,
            actions: actions,
          );
    if (action == null) return;
    final matrix = Matrix.of(context);
    if (action == AvatarAction.remove) {
      final success = await showFutureLoadingDialog(
        context: context,
        future: () => matrix.client.setAvatar(null),
      );
      if (success.error == null) {
        updateProfile();
      }
      return;
    }
    MatrixFile file;
    if (PlatformInfos.isMobile) {
      final result = await ImagePicker().pickImage(
        source: action == AvatarAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 50,
      );
      if (result == null) return;
      file = MatrixFile(bytes: await result.readAsBytes(), name: result.path);
    } else {
      final result = await selectFiles(context, type: FileType.image);
      final pickedFile = result.firstOrNull;
      if (pickedFile == null) return;
      file = MatrixFile(
        bytes: await pickedFile.readAsBytes(),
        name: pickedFile.name,
      );
    }
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => matrix.client.setAvatar(file),
    );
    if (success.error == null) {
      updateProfile();
    }
  }

  void setBannerAction() async {
    final bannerUrl = await bannerFuture;
    final actions = [
      if (PlatformInfos.isMobile)
        AdaptiveModalAction(
          value: AvatarAction.camera,
          label: L10n.of(context).openCamera,
          isDefaultAction: true,
          icon: const Icon(Icons.camera_alt_outlined),
        ),
      AdaptiveModalAction(
        value: AvatarAction.file,
        label: L10n.of(context).openGallery,
        icon: const Icon(Icons.photo_outlined),
      ),
      if (bannerUrl != null)
        AdaptiveModalAction(
          value: AvatarAction.remove,
          label: L10n.of(context).clearBanner,
          isDestructive: true,
          icon: const Icon(Icons.delete_outlined),
        ),
    ];
    final action = actions.length == 1
        ? actions.single.value
        : await showModalActionPopup<AvatarAction>(
            context: context,
            title: L10n.of(context).changeYourBanner,
            cancelLabel: L10n.of(context).cancel,
            actions: actions,
          );
    if (action == null) return;
    final matrix = Matrix.of(context);
    if (action == AvatarAction.remove) {
      final success = await showFutureLoadingDialog(
        context: context,
        future: () => matrix.client.deleteProfileField(
          matrix.client.userID!,
          AppConfig.bannerProfileField,
        ),
      );
      if (success.error == null) {
        updateBanner();
      }
      return;
    }
    MatrixFile file;
    if (PlatformInfos.isMobile) {
      final result = await ImagePicker().pickImage(
        source: action == AvatarAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 50,
      );
      if (result == null) return;
      file = MatrixFile(bytes: await result.readAsBytes(), name: result.path);
    } else {
      final result = await selectFiles(context, type: FileType.image);
      final pickedFile = result.firstOrNull;
      if (pickedFile == null) return;
      file = MatrixFile(
        bytes: await pickedFile.readAsBytes(),
        name: pickedFile.name,
      );
    }
    final success = await showFutureLoadingDialog(
      context: context,
      future: () async {
        final url = await matrix.client.uploadContent(
          file.bytes,
          filename: file.name,
          contentType: file.mimeType,
        );
        await matrix.client.setProfileField(
          matrix.client.userID!,
          AppConfig.bannerProfileField,
          {AppConfig.bannerProfileField: url.toString()},
        );
      },
    );
    if (success.error == null) {
      updateBanner();
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => checkBootstrap());

    super.initState();
  }

  void checkBootstrap() async {
    final client = Matrix.of(context).client;
    if (!client.encryptionEnabled) return;
    await client.accountDataLoading;
    await client.userDeviceKeysLoading;
    if (client.prevBatch == null) {
      await client.onSync.stream.first;
    }
    final crossSigning =
        await client.encryption?.crossSigning.isCached() ?? false;
    final needsBootstrap =
        await client.encryption?.keyManager.isCached() == false ||
        client.encryption?.crossSigning.enabled == false ||
        crossSigning == false;
    final isUnknownSession = client.isUnknownSession;
    setState(() {
      showChatBackupBanner = needsBootstrap || isUnknownSession;
    });
  }

  bool? crossSigningCached;
  bool? showChatBackupBanner;

  void firstRunBootstrapAction([dynamic _]) async {
    if (showChatBackupBanner != true) {
      showOkAlertDialog(
        context: context,
        title: L10n.of(context).chatBackup,
        message: L10n.of(context).onlineKeyBackupEnabled,
        okLabel: L10n.of(context).close,
      );
      return;
    }
    await context.push('/backup');
    checkBootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    profileFuture ??= client.getProfileFromUserId(client.userID!);
    aboutFuture ??= _getAbout();
    bannerFuture ??= _getBanner();

    return SettingsView(this);
  }
}

enum AvatarAction { camera, file, remove }
