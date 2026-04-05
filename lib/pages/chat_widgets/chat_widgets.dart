import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/pages/chat_widgets/chat_widgets_view.dart';
import 'package:extera_next/pages/chat_widgets/widget_info.dart';
import 'package:extera_next/utils/adaptive_bottom_sheet.dart';
import 'package:extera_next/widgets/matrix.dart';

class ChatWidgets extends StatefulWidget {
  final String roomId;

  const ChatWidgets({required this.roomId, super.key});

  @override
  State<StatefulWidget> createState() => ChatWidgetsController();
}

class ChatWidgetsController extends State<ChatWidgets> {
  Room get room {
    final client = Matrix.of(context).client;
    return client.getRoomById(widget.roomId)!;
  }

  // List<StrippedStateEvent> get widgetEvents {
  //   return room.states
  //           .tryGet<Map<String, StrippedStateEvent>>(
  //             'im.vector.modular.widgets',
  //           )
  //           ?.values
  //           .where((event) {
  //             final content = event.content;
  //             return content.containsKey('name') &&
  //                 content.containsKey('url') &&
  //                 content.containsKey('type');
  //           })
  //           .toList() ??
  //       <StrippedStateEvent>[];
  // }

  void onWidgetTap(MatrixWidget widget) async {
    await showAdaptiveBottomSheet(
      context: context,
      builder: (context) {
        return WidgetInfo(room: room, widget: widget);
      },
    );
  }

  @override
  Widget build(BuildContext context) => ChatWidgetsView(this);
}
