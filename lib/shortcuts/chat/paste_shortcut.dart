import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hotkey_manager/hotkey_manager.dart';

class PasteIntent extends Intent {
  const PasteIntent();
}

class ChatPasteShortcut extends StatefulWidget {
  final void Function() onPaste;
  final Widget child;

  const ChatPasteShortcut({
    required this.onPaste,
    required this.child,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => ChatPasteShortcutState();
}

class ChatPasteShortcutState extends State<ChatPasteShortcut> {
  final HotKey pasteKey = HotKey(
    key: LogicalKeyboardKey.keyV,
    modifiers: [HotKeyModifier.control],
    scope: HotKeyScope.inapp,
  );

  @override
  void initState() {
    super.initState();
    hotKeyManager.register(
      pasteKey,
      keyDownHandler: (hotKey) {
        widget.onPaste();
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    hotKeyManager.unregister(pasteKey);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
