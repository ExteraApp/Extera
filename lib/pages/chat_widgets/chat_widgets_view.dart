import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/add_widget_tile.dart';
import 'package:extera_next/pages/chat_widgets/chat_widgets.dart';
import 'package:extera_next/utils/adaptive_bottom_sheet.dart';
import 'package:extera_next/utils/stream_extension.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';
import 'package:extera_next/widgets/matrix.dart';

class ChatWidgetsView extends StatelessWidget {
  final ChatWidgetsController controller;

  const ChatWidgetsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(AppConfig.borderRadius);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).widgets)),
      body: MaxWidthBody(
        child: SingleChildScrollView(
          child: Padding(
            padding: const .symmetric(horizontal: 8),
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Material(
                  borderRadius: borderRadius,
                  color: theme.colorScheme.surfaceContainerHigh,
                  clipBehavior: .hardEdge,
                  child: StreamBuilder(
                    stream: client.onRoomState.stream
                        .where(
                          (event) => event.roomId == controller.widget.roomId,
                        )
                        .rateLimit(const Duration(seconds: 1)),
                    builder: (context, _) {
                      return Column(
                        children: controller.room.widgets
                            .map(
                              (widget) => ListTile(
                                leading: Icon(
                                  ({
                                        'm.jitsi': Icons.video_call_outlined,
                                        'm.tradingview': Icons.trending_up,
                                        'm.spotify': Icons.music_note,
                                        'm.video':
                                            Icons.video_collection_outlined,
                                        'm.googledoc': Icons.edit_document,
                                        'm.googlecalendar':
                                            Icons.calendar_month,
                                        'm.etherpad': Icons.note_alt_outlined,
                                        'm.grafana': Icons.analytics_outlined,
                                        'm.custom': Icons.widgets_outlined,
                                      }).tryGet(widget.type) ??
                                      Icons.widgets_outlined,
                                ),
                                title: Text(widget.name ?? "Widget"),
                                // subtitle: ,
                                onTap: () {
                                  controller.onWidgetTap(widget);
                                },
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (controller.room.canChangeStateEvent(
                  'im.vector.modular.widgets',
                ))
                  Material(
                    borderRadius: borderRadius,
                    color: theme.colorScheme.surfaceContainerHigh,
                    clipBehavior: .hardEdge,
                    child: ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(L10n.of(context).addWidget),
                      onTap: () {
                        showAdaptiveBottomSheet(
                          context: context,
                          builder: (context) {
                            return AddWidgetTile(room: controller.room);
                          },
                        );
                      },
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
