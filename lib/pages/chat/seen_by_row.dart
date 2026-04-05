import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/utils/adaptive_bottom_sheet.dart';
import 'package:extera_next/utils/date_time_extension.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/room_status_extension.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/list_divider.dart';
import 'package:extera_next/widgets/matrix.dart';

class SeenByRow extends StatelessWidget {
  final ChatController controller;
  const SeenByRow(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final receipts = controller.room.getReceipts(controller.timeline!);
    const maxAvatars = 7;
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: AnimatedContainer(
        constraints: const BoxConstraints(
          maxWidth: FluffyThemes.columnWidth * 2.5,
        ),
        height: receipts.isEmpty ? 0 : 24,
        duration: receipts.isEmpty
            ? Duration.zero
            : FluffyThemes.animationDuration,
        curve: FluffyThemes.animationCurve,
        alignment:
            controller.timeline!.events.isNotEmpty &&
                controller.timeline!.events.first.senderId ==
                    Matrix.of(context).client.userID
            ? Alignment.topRight
            : Alignment.topLeft,
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
        child: GestureDetector(
          onLongPress: () {
            SeenByDialog(receipts).show(context);
          },
          onTap: () {
            // single tap for desktop
            if (!PlatformInfos.isMobile) {
              SeenByDialog(receipts).show(context);
            }
          },
          child: Wrap(
            spacing: 4,
            children: [
              ...(receipts.length > maxAvatars
                      ? receipts.sublist(0, maxAvatars)
                      : receipts)
                  .map(
                    (receipt) => Avatar(
                      mxContent: receipt.user.avatarUrl,
                      name: receipt.user.calcDisplayname(),
                      size: 16,
                    ),
                  ),
              if (receipts.length > maxAvatars)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    child: Center(
                      child: Text(
                        '+${receipts.length - maxAvatars}',
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SeenByDialog extends StatelessWidget {
  final List<Receipt> receipts;

  const SeenByDialog(this.receipts, {super.key});

  Future<bool?> show(BuildContext context) =>
      showAdaptiveBottomSheet(context: context, builder: (context) => this);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).readReceipts)),
      body: Padding(
        padding: const .all(8),
        child: Material(
          clipBehavior: .hardEdge,
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          child: ListView.builder(
            itemCount: receipts.length,
            itemBuilder: (context, i) {
              final receipt = receipts[i];
              return Column(
                children: [
                  ListTile(
                    leading: Avatar(
                      mxContent: receipt.user.avatarUrl,
                      name: receipt.user.displayName,
                      size: 24,
                    ),
                    title: Text(receipt.user.calcDisplayname()),
                    subtitle: Text(receipt.time.localizedTime(context)),
                  ),
                  const ListDivider(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
