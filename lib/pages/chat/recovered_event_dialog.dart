import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/events/message.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';

class RecoveredEventDialog extends StatefulWidget {
  final Event event;
  final Timeline timeline;

  const RecoveredEventDialog({
    required this.event,
    required this.timeline,
    super.key,
  });

  @override
  RecoveredEventDialogState createState() => RecoveredEventDialogState();
}

class RecoveredEventDialogState extends State<RecoveredEventDialog> {
  Event get event => widget.event;
  Timeline get timeline => widget.timeline;

  RecoveredEventDialogState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = [theme.secondaryBubbleColor, theme.bubbleColor];

    final message = Message(
      event,
      colors: colors,
      onInfoTab: (Event ev) => {},
      onMention: () => {},
      onSelect: (Event ev, Offset? tapPosition) => {},
      onSwipe: () => {},
      scrollToEventId: (String p0) => {},
      timeline: timeline,
      animateIn: false,
      displayReadMarker: false,
      highlightMarker: false,
      longPressSelect: false,
      selected: false,
      wallpaperMode: false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).recoveredMessage)),
      body: MaxWidthBody(child: message),
    );
  }
}
