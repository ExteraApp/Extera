import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/pages/chat_threads/chat_threads_view.dart';
import 'package:extera_next/widgets/matrix.dart';

class ChatThreads extends StatefulWidget {
  final String roomId;

  const ChatThreads({super.key, required this.roomId});

  @override
  State<StatefulWidget> createState() => ChatThreadsController();
}

class ChatThreadsController extends State<ChatThreads> {
  Map<String, Thread>? threadsMap;
  bool _isLoading = false;

  final ScrollController scrollController = ScrollController();

  Room? get room {
    final client = Matrix.of(context).client;
    return client.getRoomById(widget.roomId);
  }

  List<Event> get threads {
    if (threadsMap == null) return [];
    return threadsMap!.values.map((thread) => thread.rootEvent).toList()
      ..sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
  }

  bool get isLoading => _isLoading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && room != null) {
        _loadThreads();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadThreads() async {
    if (_isLoading) return;

    final currentRoom = room;
    if (currentRoom == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final threadsMap = await currentRoom.getThreads();
      if (mounted) {
        setState(() {
          this.threadsMap = threadsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading threads: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> refresh() async {
    await _loadThreads();
  }

  void openThread(Event event) {
    final currentRoom = room;
    if (currentRoom == null) return;

    context.go('/rooms/${event.roomId}/threads/${event.eventId}');
  }

  @override
  Widget build(BuildContext context) => ChatThreadsView(this);
}
