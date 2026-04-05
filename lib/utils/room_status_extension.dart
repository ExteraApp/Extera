import 'package:flutter/widgets.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import '../config/app_config.dart';

extension RoomStatusExtension on Room {
  String getLocalizedTypingText(BuildContext context) {
    var typingText = '';
    final typingUsers = this.typingUsers;
    typingUsers.removeWhere((User u) => u.id == client.userID);

    if (AppConfig.hideTypingUsernames) {
      typingText = L10n.of(context).isTyping;
      if (typingUsers.first.id != directChatMatrixID) {
        typingText = L10n.of(context).numUsersTyping(typingUsers.length);
      }
    } else if (typingUsers.length == 1) {
      typingText = L10n.of(context).isTyping;
      if (typingUsers.first.id != directChatMatrixID) {
        typingText = L10n.of(
          context,
        ).userIsTyping(typingUsers.first.calcDisplayname());
      }
    } else if (typingUsers.length == 2) {
      typingText = L10n.of(context).userAndUserAreTyping(
        typingUsers.first.calcDisplayname(),
        typingUsers[1].calcDisplayname(),
      );
    } else if (typingUsers.length > 2) {
      typingText = L10n.of(context).userAndOthersAreTyping(
        typingUsers.first.calcDisplayname(),
        (typingUsers.length - 1),
      );
    }
    return typingText;
  }

  List<Receipt> getReceipts(Timeline timeline, {String? eventId}) {
    if (timeline.events.isEmpty) return [];
    eventId ??= timeline.events.first.eventId;
    // print(eventId);

    final lastReceipts = <Receipt>{};
    // now we iterate the timeline events until we hit the first rendered event
    for (final event in timeline.events) {
      lastReceipts.addAll(event.receipts);
      if (event.eventId == eventId) {
        break;
      }
    }
    lastReceipts.removeWhere(
      (receipt) =>
          receipt.user.id == client.userID ||
          receipt.user.id == timeline.events.first.senderId,
    );
    return lastReceipts.toList();
  }

  bool hasBeenReadBySomeone(Timeline timeline, String eventId) {
    if (timeline.events.isEmpty) return false;
    for (final event in timeline.events) {
      if (event.receipts
          .where((receipt) => receipt.user.id != client.userID!)
          .isNotEmpty) {
        return true;
      }
      if (event.eventId == eventId) {
        break;
      }
    }
    return true;
  }

  String? getLatestReadMessage(Timeline timeline) {
    if (timeline.events.isEmpty) return null;
    for (final event in timeline.events) {
      if (event.receipts
          .where((receipt) => receipt.user.id != client.userID!)
          .isNotEmpty) {
        return event.eventId;
      }
    }
    return null;
  }
}
