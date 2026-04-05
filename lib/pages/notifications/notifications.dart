import 'package:flutter/material.dart' hide Notification;

import 'package:matrix/matrix.dart';

import 'package:extera_next/pages/notifications/notifications_view.dart';
import 'package:extera_next/widgets/matrix.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<StatefulWidget> createState() => NotificationsController();
}

class NotificationsController extends State<Notifications> {
  List<Notification>? notifications;
  String? nextToken;

  bool isLoadingNotifications = false;
  bool showOnlyMentions = false;

  void loadNotifications() async {
    if (isLoadingNotifications) {
      return;
    }
    setState(() {
      isLoadingNotifications = true;
    });
    final client = Matrix.of(context).client;
    final notificationsResponse = await client.getNotifications(
      from: nextToken,
      only: showOnlyMentions ? 'highlight' : null,
    );
    nextToken = notificationsResponse.nextToken;
    setState(() {
      notifications = notificationsResponse.notifications;
      isLoadingNotifications = false;
    });
  }

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  void setOnlyMentions(bool onlyMentions) {
    setState(() {
      showOnlyMentions = onlyMentions;
      nextToken = null;
      notifications = [];
      loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) => NotificationsView(this);
}
