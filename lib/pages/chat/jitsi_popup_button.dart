import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';
import 'package:uuid/v4.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import 'package:extera_next/widgets/future_loading_snackbar.dart';

// import 'package:extera_next/widgets/matrix.dart';

class JitsiPopupButton extends StatelessWidget {
  final Room room;
  const JitsiPopupButton(this.room, {super.key});

  Future<void> _startCall(BuildContext context, bool isAudioOnly) async {
    final urlResult = await showFutureLoadingDialog(
      context: context,
      future: () async {
        final conferenceId = UuidV4().generate();
        final domain = AppSettings.jitsiDomain.value;
        final uri = Uri(
          scheme: 'https',
          host: domain,
          path: conferenceId,
          fragment: isAudioOnly ? 'config.startWithVideoMuted=true' : null,
        );
        await room.addWidget(
          MatrixWidget(
            room: room,
            name: 'Jitsi Meet',
            type: 'jitsi',
            url: uri.toString(),
            data: {
              'domain': domain,
              'isAudioOnly': isAudioOnly,
              'conferenceId': conferenceId,
              'roomName': room.getLocalizedDisplayname(
                MatrixLocals(L10n.of(context)),
              ),
            },
          ),
        );
        return uri;
      },
    );
    final url = urlResult.result;
    if (url == null) return;
    UrlLauncher(context, url.toString()).launchUrl();
  }

  Future<void> _endAllCalls(BuildContext context) async {
    final l10n = L10n.of(context);
    final consent = await showOkCancelAlertDialog(
      context: context,
      title: l10n.removeCallFromChat,
      message: l10n.removeCallFromChatDescription,
      okLabel: l10n.remove,
    );

    if (consent != OkCancelResult.ok) return;
    if (!context.mounted) return;
    showFutureLoadingSnackbar(
      context: context,
      future: () async {
        final activeJitsiCalls = room
            .states['im.vector.modular.widgets']
            ?.values
            .where((state) => state.content['type'] == 'jitsi');
        if (activeJitsiCalls == null) return;
        for (final call in activeJitsiCalls) {
          await room.deleteWidget(call.stateKey!);
        }
      },
    );
  }

  Future<void> _launchJitsiWidget(
    BuildContext context,
    MatrixWidget widget,
  ) async {
    final theme = Theme.of(context);
    final isAudioOnly = widget.data?.tryGet<bool>('isAudioOnly') ?? false;
    final domain = widget.data?.tryGet<String>('domain');
    final conferenceId = widget.data?.tryGet<String>('conferenceId');

    if (domain == null || conferenceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Invalid conference data",
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
          backgroundColor: theme.colorScheme.errorContainer,
        ),
      );
      return;
    }

    // final client = Matrix.of(context).client;
    // final profile = await client.getUserProfile(client.userID!);

    final uri = Uri(
      scheme: 'https',
      host: domain,
      path: '/$conferenceId',
      fragment: isAudioOnly ? 'config.startWithVideoMuted=true' : null,
    );

    final url = uri.toString();

    UrlLauncher(context, url).launchUrl();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final activeJitsiCalls = room.widgets
        .where((widget) => widget.type == 'jitsi')
        // .map((widget) {
        //   final isAudioOnly = widget.data?.tryGet<bool>('isAudioOnly') ?? false;
        //   final domain = widget.data?.tryGet<String>('domain');
        //   final conferenceId = widget.data?.tryGet<String>('conferenceId');
        //   return (
        //     isAudioOnly: isAudioOnly,
        //     domain: domain,
        //     conferenceId: conferenceId,
        //   );
        // })
        .toList();
    final canEditCalls = room.canChangeStateEvent('im.vector.modular.widgets');
    if (activeJitsiCalls.isEmpty && !canEditCalls) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton(
      itemBuilder: (context) => [
        ...activeJitsiCalls.map(
          (call) => PopupMenuItem(
            onTap: () => _launchJitsiWidget(context, call),
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  (call.data?.tryGet<bool>('isAudioOnly') ?? false)
                      ? Icons.add_call
                      : Icons.video_call,
                ),
                const SizedBox(width: 12),
                Text(
                  (call.data?.tryGet<bool>('isAudioOnly') ?? false)
                      ? l10n.joinVoiceCall
                      : l10n.joinVideoCall,
                ),
              ],
            ),
          ),
        ),
        if (canEditCalls) ...[
          if (activeJitsiCalls.isEmpty) ...[
            PopupMenuItem(
              onTap: () => _startCall(context, true),
              child: Row(
                mainAxisSize: .min,
                children: [
                  const Icon(Icons.add_call),
                  const SizedBox(width: 12),
                  Text(l10n.startVoiceCall),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => _startCall(context, false),
              child: Row(
                mainAxisSize: .min,
                children: [
                  const Icon(Icons.video_call),
                  const SizedBox(width: 12),
                  Text(l10n.startVideoCall),
                ],
              ),
            ),
          ] else
            PopupMenuItem(
              onTap: () => _endAllCalls(context),
              child: Row(
                mainAxisSize: .min,
                children: [
                  Icon(
                    Icons.call_end_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.removeCallForEveryone,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
      icon: Badge(
        label: Text(l10n.live),
        isLabelVisible: activeJitsiCalls.isNotEmpty,
        child: Icon(Icons.video_call_outlined),
      ),
    );
  }
}
