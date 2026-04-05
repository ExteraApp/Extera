import 'package:flutter/material.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/download_manager/download_manager.dart';
import 'package:extera_next/utils/adaptive_bottom_sheet.dart';
import 'package:extera_next/widgets/layouts/max_width_body.dart';

class DownloadManagerView extends StatelessWidget {
  const DownloadManagerView({super.key});

  static void showDownloads(BuildContext context) {
    showAdaptiveBottomSheet(
      context: context,
      builder: (context) => const DownloadManagerView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dlm = DownloadManager.of(context);
    return Scaffold(
      body: MaxWidthBody(
        child: ListView.builder(
          itemCount: dlm.downloads.length,
          itemBuilder: (context, index) {
            final download = dlm.downloads[index];
            return ListTile(
              title: Text(download.name),
              subtitle: LinearProgressIndicator(
                value: download.progress / 100,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  download.cancel();
                },
                child: Text(L10n.of(context).cancel),
              ),
            );
          },
        ),
      ),
      appBar: AppBar(
        title: Text(L10n.of(context).downloads, textAlign: TextAlign.center),
      ),
    );
  }
}
