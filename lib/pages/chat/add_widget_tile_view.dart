import 'package:flutter/material.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/add_widget_tile.dart';

class AddWidgetTileView extends StatelessWidget {
  final AddWidgetTileState controller;

  const AddWidgetTileView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).addWidget)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const .symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: .max,
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ...{
                    'm.etherpad': Text(L10n.of(context).widgetEtherpad),
                    'm.jitsi': Text(L10n.of(context).widgetJitsi),
                    'm.video': Text(L10n.of(context).widgetVideo),
                    'm.custom': Text(L10n.of(context).widgetCustom),
                  }.entries.map(
                    (entry) => ButtonSegment<String>(
                      value: entry.key,
                      label: entry.value,
                    ),
                  ),
                ],
                selected: {controller.widgetType},
                onSelectionChanged: (Set<String> newSelection) {
                  controller.setWidgetType(newSelection.first);
                },
              ),
              Padding(
                padding: const .symmetric(vertical: 8.0),
                child: TextField(
                  controller: controller.nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.label),
                    label: Text(L10n.of(context).widgetName),
                    errorText: controller.nameError,
                  ),
                ),
              ),
              Padding(
                padding: const .symmetric(vertical: 4.0),
                child: TextField(
                  controller: controller.urlController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.add_link),
                    label: Text(L10n.of(context).link),
                    errorText: controller.urlError,
                  ),
                ),
              ),
              Row(
                mainAxisSize: .max,
                mainAxisAlignment: .end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    child: Text(L10n.of(context).cancel),
                  ),
                  const SizedBox(width: 18),
                  FilledButton(
                    onPressed: controller.addWidget,
                    child: Text(L10n.of(context).addWidget),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
