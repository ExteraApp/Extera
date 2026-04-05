import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/utils/poll_events.dart';
import '../../config/app_config.dart';

extension VisibleInGuiExtension on List<Event> {
  List<Event> filterByThreaded(bool threaded) {
    return where(
      (e) =>
          e.isThreaded == threaded ||
          e.relationshipType == RelationshipTypes.edit ||
          e.relationshipType == RelationshipTypes.reaction,
    ).toList();
  }

  List<Event> filterThreadRoots() {
    return where((e) => e.room.threads.containsKey(e.eventId)).toList();
  }

  List<Event> filterByVisibleInGui({String? exceptionEventId}) {
    final visibleEvents = where(
      (e) => e.isVisibleInGui || e.eventId == exceptionEventId,
    ).toList();

    // Hide creation state events:
    if (visibleEvents.isNotEmpty &&
        visibleEvents.last.type == EventTypes.RoomCreate) {
      var i = visibleEvents.length - 2;
      while (i > 0) {
        final event = visibleEvents[i];
        if (!event.isState) break;
        if (event.type == EventTypes.Encryption) {
          i--;
          continue;
        }
        if (event.type == EventTypes.RoomMember &&
            event.roomMemberChangeType == RoomMemberChangeType.acceptInvite) {
          i--;
          continue;
        }
        visibleEvents.removeAt(i);
        i--;
      }
    }
    return visibleEvents;
  }
}

extension IsStateExtension on Event {
  bool get isVisibleInGui =>
      // always filter out edit and reaction relationships
      !{
        RelationshipTypes.edit,
        RelationshipTypes.reaction,
      }.contains(relationshipType) &&
      // always filter out m.key.* events
      !type.startsWith('m.key.verification.') &&
      // event types to hide: redaction and reaction events
      // if a reaction has been redacted we also want it to be hidden in the timeline
      !{EventTypes.Reaction, EventTypes.Redaction}.contains(type) &&
      // if we enabled to hide all redacted events, don't show those
      (!AppSettings.hideRedactedEvents.value || !redacted) &&
      // if we enabled to hide all unknown events, don't show those
      (!AppSettings.hideUnknownEvents.value ||
          isEventTypeKnown ||
          type == PollEvents.PollStart) &&
      // remove state events that we don't want to render
      (isState || !AppConfig.hideAllStateEvents) &&
      // hide simple join/leave member events in public rooms
      (!AppSettings.hideMemberChangesInPublicChats.value ||
          type != EventTypes.RoomMember ||
          room.joinRules != JoinRules.public ||
          content.tryGet<String>('membership') == 'ban' ||
          stateKey != senderId);

  bool get isThreaded =>
      relationshipEventId != null &&
      relationshipType == RelationshipTypes.thread;

  bool get isState => stateKey != null;
}
