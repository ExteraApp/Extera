import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hotkey_manager/hotkey_manager.dart';

class NextChatIntent extends Intent {
  const NextChatIntent();
}

class PreviousChatIntent extends Intent {
  const PreviousChatIntent();
}

class ChatListShortcuts extends StatefulWidget {
  final void Function() onPreviousChat;
  final void Function() onNextChat;
  final Widget child;

  ChatListShortcuts({
    required this.onPreviousChat,
    required this.onNextChat,
    required this.child,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => ChatListShortcutsState();
}

class ChatListShortcutsState extends State<ChatListShortcuts> {
  final HotKey prevChatKey = HotKey(
    key: LogicalKeyboardKey.arrowUp,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.inapp,
  );

  final HotKey nextChatKey = HotKey(
    key: LogicalKeyboardKey.arrowDown,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.inapp,
  );

  @override
  void initState() {
    super.initState();
    hotKeyManager.register(
      prevChatKey,
      keyDownHandler: (hotKey) {
        widget.onPreviousChat();
      },
    );
    hotKeyManager.register(
      nextChatKey,
      keyDownHandler: (hotKey) {
        widget.onNextChat();
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    hotKeyManager.unregister(prevChatKey);
    hotKeyManager.unregister(nextChatKey);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
