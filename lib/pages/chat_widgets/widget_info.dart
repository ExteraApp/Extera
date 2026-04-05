import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/future_loading_snackbar.dart';

class WidgetInfo extends StatelessWidget {
  final MatrixWidget widget;
  final Room room;

  const WidgetInfo({required this.room, required this.widget, super.key});

  void onOpenTap(BuildContext context) async {
    final uri = await widget.buildWidgetUrl();

    if (uri.scheme != 'https') return;

    UrlLauncher(context, uri.toString()).launchUrl();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).widget)),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(widget.name ?? 'Widget'),
            subtitle: Text(L10n.of(context).widgetName),
          ),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title:
                {
                  'm.etherpad': Text(L10n.of(context).widgetEtherpad),
                  'm.jitsi': Text(L10n.of(context).widgetJitsi),
                  'm.video': Text(L10n.of(context).widgetVideo),
                  'm.custom': Text(L10n.of(context).widgetCustom),
                }.tryGet(widget.type) ??
                Text(L10n.of(context).widget),
            subtitle: Text(L10n.of(context).widgetType),
          ),
          if (widget.creatorUserId != null)
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: Text(widget.creatorUserId!),
              subtitle: Text(L10n.of(context).widgetCreatorUser),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.open_in_browser_outlined),
            title: Text(L10n.of(context).open),
            onTap: () {
              Navigator.of(context).pop();
              onOpenTap(context);
            },
          ),
          if (room.canChangeStateEvent('im.vector.modular.widgets'))
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: Text(L10n.of(context).deleteWidget),
              onTap: () {
                showFutureLoadingSnackbar(
                  context: context,
                  future: () => room.deleteWidget(widget.id!),
                );
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
