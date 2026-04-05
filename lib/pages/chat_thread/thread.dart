import 'package:flutter/material.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/chat.dart';
import 'package:extera_next/widgets/matrix.dart';
import 'package:extera_next/widgets/share_scaffold_dialog.dart';

class ThreadPage extends StatelessWidget {
  final String roomId;
  final List<ShareItem>? shareItems;
  final String? threadRootEventId;
  final String? eventId;

  const ThreadPage({
    super.key,
    required this.roomId,
    required this.threadRootEventId,
    this.eventId,
    this.shareItems,
  });

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final room = client.getRoomById(roomId);
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(L10n.of(context).oopsSomethingWentWrong)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(L10n.of(context).youAreNoLongerParticipatingInThisChat),
          ),
        ),
      );
    }

    final thread = room.threads[threadRootEventId];

    return ChatPageWithRoom(
      key: Key('chat_page_${roomId}_${threadRootEventId}_$eventId'),
      room: room,
      thread: thread,
      shareItems: shareItems,
      eventId: eventId,
    );
  }
}
