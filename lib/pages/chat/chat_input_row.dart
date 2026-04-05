import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/recording_input_row.dart';
import 'package:extera_next/pages/chat/recording_view_model.dart';
import 'package:extera_next/pages/chat/video_note_recording_dialog.dart';
import 'package:extera_next/shortcuts/chat/paste_shortcut.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/matrix.dart';
import '../../config/themes.dart';
import 'chat.dart';
import 'input_bar.dart';

class ChatInputRow extends StatelessWidget {
  final ChatController controller;

  static const double height = 48.0;

  const ChatInputRow(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final selectedTextButtonStyle = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurface,
    );

    return RecordingViewModel(
      builder: (context, recordingViewModel) {
        if (recordingViewModel.isRecording) {
          return RecordingInputRow(
            state: recordingViewModel,
            onSend: controller.onVoiceMessageSend,
            onVideoSend: controller.onVideoNoteSend,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: controller.selectMode
              ? <Widget>[
                  if (controller.selectedEvents.every(
                    (event) => event.status == EventStatus.error,
                  ))
                    SizedBox(
                      height: height,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        onPressed: controller.deleteErrorEventsAction,
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.delete_forever_outlined),
                            Text(L10n.of(context).delete),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: height,
                      child: TextButton(
                        style: selectedTextButtonStyle,
                        onPressed: controller.forwardEventsAction,
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.keyboard_arrow_left_outlined),
                            Text(L10n.of(context).forward),
                          ],
                        ),
                      ),
                    ),
                  controller.selectedEvents.length == 1
                      ? controller.selectedEvents.first
                                .getDisplayEvent(controller.timeline!)
                                .status
                                .isSent
                            ? SizedBox(
                                height: height,
                                child: TextButton(
                                  style: selectedTextButtonStyle,
                                  onPressed: controller.replyAction,
                                  child: Row(
                                    children: <Widget>[
                                      Text(L10n.of(context).reply),
                                      const Icon(Icons.keyboard_arrow_right),
                                    ],
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: height,
                                child: TextButton(
                                  style: selectedTextButtonStyle,
                                  onPressed: controller.sendAgainAction,
                                  child: Row(
                                    children: <Widget>[
                                      Text(L10n.of(context).tryToSendAgain),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.send_outlined, size: 16),
                                    ],
                                  ),
                                ),
                              )
                      : const SizedBox.shrink(),
                ]
              : <Widget>[
                  const SizedBox(width: 4),
                  AnimatedContainer(
                    duration: FluffyThemes.animationDuration,
                    curve: FluffyThemes.animationCurve,
                    width: controller.sendController.text.isNotEmpty
                        ? 0
                        : height,
                    height: height,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(),
                    clipBehavior: Clip.hardEdge,
                    child: PopupMenuButton<String>(
                      useRootNavigator: false,
                      icon: const Icon(Icons.add_circle_outline),
                      iconColor: theme.colorScheme.onSurface,
                      onSelected: controller.onAddPopupMenuButtonSelected,
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            if (PlatformInfos.isMobile)
                              PopupMenuItem<String>(
                                value: 'location',
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        theme.colorScheme.onPrimaryContainer,
                                    foregroundColor:
                                        theme.colorScheme.primaryContainer,
                                    child: const Icon(Icons.gps_fixed_outlined),
                                  ),
                                  title: Text(L10n.of(context).shareLocation),
                                  contentPadding: const EdgeInsets.all(0),
                                ),
                              ),
                            PopupMenuItem<String>(
                              value: 'image',
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.onPrimaryContainer,
                                  foregroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: const Icon(Icons.photo_outlined),
                                ),
                                title: Text(L10n.of(context).sendImage),
                                contentPadding: const EdgeInsets.all(0),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'video',
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.onPrimaryContainer,
                                  foregroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: const Icon(
                                    Icons.video_camera_back_outlined,
                                  ),
                                ),
                                title: Text(L10n.of(context).sendVideo),
                                contentPadding: const EdgeInsets.all(0),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'file',
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.onPrimaryContainer,
                                  foregroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: const Icon(Icons.attachment_outlined),
                                ),
                                title: Text(L10n.of(context).sendFile),
                                contentPadding: const EdgeInsets.all(0),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'poll',
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.onPrimaryContainer,
                                  foregroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: const Icon(Icons.poll_outlined),
                                ),
                                title: Text(L10n.of(context).createPoll),
                                contentPadding: const EdgeInsets.all(0),
                              ),
                            ),
                          ],
                    ),
                  ),
                  if (PlatformInfos.isMobile)
                    AnimatedContainer(
                      duration: FluffyThemes.animationDuration,
                      curve: FluffyThemes.animationCurve,
                      width: controller.sendController.text.isNotEmpty
                          ? 0
                          : height,
                      height: height,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(),
                      clipBehavior: Clip.hardEdge,
                      child: PopupMenuButton(
                        useRootNavigator: false,
                        icon: const Icon(Icons.camera_alt_outlined),
                        onSelected: controller.onAddPopupMenuButtonSelected,
                        iconColor: theme.colorScheme.onSurface,
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'camera-video',
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.onPrimaryContainer,
                                foregroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: const Icon(Icons.videocam_outlined),
                              ),
                              title: Text(L10n.of(context).recordAVideo),
                              contentPadding: const EdgeInsets.all(0),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'camera',
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.onPrimaryContainer,
                                foregroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: const Icon(Icons.camera_alt_outlined),
                              ),
                              title: Text(L10n.of(context).takeAPhoto),
                              contentPadding: const EdgeInsets.all(0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    height: height,
                    width: height,
                    alignment: Alignment.center,
                    child: IconButton(
                      tooltip: L10n.of(context).emojis,
                      color: theme.colorScheme.onSurface,
                      icon: Icon(
                        controller.showEmojiPicker
                            ? Icons.keyboard
                            : Icons.add_reaction_outlined,
                        key: ValueKey(controller.showEmojiPicker),
                      ),
                      onPressed: controller.emojiPickerAction,
                    ),
                  ),
                  if (Matrix.of(context).isMultiAccount &&
                      Matrix.of(context).hasComplexBundles &&
                      Matrix.of(context).currentBundle!.length > 1)
                    Container(
                      height: height,
                      width: height,
                      alignment: Alignment.center,
                      child: _ChatAccountPicker(controller),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.0),
                      child: ChatPasteShortcut(
                        onPaste: () {
                          controller.sendImageFromClipBoard(null);
                        },
                        child: InputBar(
                          room: controller.room,
                          minLines: 1,
                          maxLines: 8,
                          autofocus: !PlatformInfos.isMobile,
                          keyboardType: TextInputType.multiline,
                          textInputAction:
                              AppSettings.sendOnEnter.value &&
                                  PlatformInfos.isMobile
                              ? TextInputAction.send
                              : null,
                          onSubmitted: controller.onInputBarSubmitted,
                          onSubmitImage: controller.sendImageFromClipBoard,
                          focusNode: controller.inputFocus,
                          controller: controller.sendController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(
                              left: 6.0,
                              right: 6.0,
                              bottom: 6.0,
                              top: 3.0,
                            ),
                            counter: const SizedBox.shrink(),
                            hintText: L10n.of(context).writeAMessage,
                            hintMaxLines: 1,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            filled: false,
                          ),
                          onChanged: controller.onInputBarChanged,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: height,
                    width: height,
                    alignment: Alignment.center,
                    child:
                        PlatformInfos.platformCanRecord &&
                            controller.sendController.text.isEmpty
                        ? IconButton(
                            tooltip:
                                recordingViewModel.recordingMode ==
                                    RecordingMode.video
                                ? L10n.of(context).videoNote
                                : L10n.of(context).voiceMessage,
                            onPressed: () {
                              // On tap: show tip and toggle mode if video notes enabled
                              final videoNotesEnabled =
                                  AppSettings.enableVideoNotes.value &&
                                  PlatformInfos.isMobile;
                              if (videoNotesEnabled) {
                                final newMode =
                                    recordingViewModel.recordingMode ==
                                        RecordingMode.audio
                                    ? RecordingMode.video
                                    : RecordingMode.audio;
                                recordingViewModel.setRecordingMode(newMode);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    margin: const EdgeInsets.only(
                                      bottom: height + 16,
                                      left: 16,
                                      right: 16,
                                      top: 16,
                                    ),
                                    showCloseIcon: true,
                                    content: Text(
                                      newMode == RecordingMode.video
                                          ? L10n.of(
                                              context,
                                            ).longPressToRecordVideoNote
                                          : L10n.of(
                                              context,
                                            ).longPressToRecordVoiceMessage,
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    margin: const EdgeInsets.only(
                                      bottom: height + 16,
                                      left: 16,
                                      right: 16,
                                      top: 16,
                                    ),
                                    showCloseIcon: true,
                                    content: Text(
                                      L10n.of(
                                        context,
                                      ).longPressToRecordVoiceMessage,
                                    ),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
                              if (recordingViewModel.recordingMode ==
                                  RecordingMode.video) {
                                // Open full-screen video note dialog
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    fullscreenDialog: true,
                                    builder: (_) => VideoNoteRecordingDialog(
                                      room: controller.room,
                                      onVideoSend: controller.onVideoNoteSend,
                                    ),
                                  ),
                                );
                              } else {
                                recordingViewModel.startRecording(
                                  controller.room,
                                );
                              }
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: theme.bubbleColor,
                              foregroundColor: theme.onBubbleColor,
                            ),
                            icon: Icon(
                              recordingViewModel.recordingMode ==
                                      RecordingMode.video
                                  ? Icons.camera_alt_outlined
                                  : Icons.mic_none_outlined,
                            ),
                          )
                        : IconButton(
                            tooltip: L10n.of(context).send,
                            onPressed: controller.send,
                            style: IconButton.styleFrom(
                              backgroundColor: theme.bubbleColor,
                              foregroundColor: theme.onBubbleColor,
                            ),
                            icon: const Icon(Icons.send_outlined),
                          ),
                  ),
                ],
        );
      },
    );
  }
}

class _ChatAccountPicker extends StatelessWidget {
  final ChatController controller;

  const _ChatAccountPicker(this.controller);

  void _popupMenuButtonSelected(String mxid, BuildContext context) {
    final client = Matrix.of(
      context,
    ).currentBundle!.firstWhere((cl) => cl!.userID == mxid, orElse: () => null);
    if (client == null) {
      Logs().w('Attempted to switch to a non-existing client $mxid');
      return;
    }
    controller.setSendingClient(client);
  }

  @override
  Widget build(BuildContext context) {
    final clients = controller.currentRoomBundle;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FutureBuilder<Profile>(
        future: controller.sendingClient.fetchOwnProfile(),
        builder: (context, snapshot) => PopupMenuButton<String>(
          useRootNavigator: false,
          onSelected: (mxid) => _popupMenuButtonSelected(mxid, context),
          itemBuilder: (BuildContext context) => clients
              .map(
                (client) => PopupMenuItem<String>(
                  value: client!.userID,
                  child: FutureBuilder<Profile>(
                    future: client.fetchOwnProfile(),
                    builder: (context, snapshot) => ListTile(
                      leading: Avatar(
                        mxContent: snapshot.data?.avatarUrl,
                        name:
                            snapshot.data?.displayName ??
                            client.userID!.localpart,
                        size: 20,
                      ),
                      title: Text(snapshot.data?.displayName ?? client.userID!),
                      contentPadding: const EdgeInsets.all(0),
                    ),
                  ),
                ),
              )
              .toList(),
          child: Avatar(
            mxContent: snapshot.data?.avatarUrl,
            name:
                snapshot.data?.displayName ??
                Matrix.of(context).client.userID!.localpart,
            size: 20,
          ),
        ),
      ),
    );
  }
}
