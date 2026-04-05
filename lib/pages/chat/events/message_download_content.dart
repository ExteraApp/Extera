import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/events/html_message.dart';
import 'package:extera_next/pages/download_manager/download_manager.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:extera_next/utils/url_launcher.dart';

class MessageDownloadContent extends StatefulWidget {
  final Event event;
  final Color textColor;
  final Color linkColor;

  const MessageDownloadContent(
    this.event, {
    required this.textColor,
    required this.linkColor,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => MessageDownloadContentState();
}

class MessageDownloadContentState extends State<MessageDownloadContent> {
  bool isDownloading = false;
  bool downloadSuccess = false;
  bool downloadError = false;
  double downloadProgress = 0.0;

  DownloadEventSubscription? _downloadSubscription;

  void subscribe() {
    final dlm = DownloadManager.of(context);

    _downloadSubscription = dlm.onEventFor(
      widget.event.attachmentMxcUrl.toString(),
      (event) {
        if (!mounted) return;

        switch (event) {
          case DownloadStartEvent():
            setState(() {
              downloadProgress = 0.0;
              downloadError = false;
              downloadSuccess = false;
              isDownloading = true;
            });
          case DownloadProgressEvent(:final progress):
            setState(() {
              isDownloading = true;
              downloadProgress = progress;
            });
          case DownloadEndEvent(:final success, :final error):
            setState(() {
              isDownloading = false;
              downloadError = !success && error != null;
              downloadSuccess = success;
            });
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    subscribe();
  }

  // 4. Override dispose to cancel the listener
  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (Your existing build code remains exactly the same)
    final event = widget.event;
    final filename =
        widget.event.content.tryGet<String>('filename') ?? widget.event.body;
    final filetype = (filename.contains('.')
        ? filename.split('.').last.toUpperCase()
        : widget.event.content
                  .tryGetMap<String, dynamic>('info')
                  ?.tryGet<String>('mimetype')
                  ?.toUpperCase() ??
              'UNKNOWN');
    final sizeString = widget.event.sizeString ?? '?MB';
    final fileDescription = widget.event.fileDescription;

    final textColor = widget.textColor;
    final linkColor = widget.linkColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
            onTap: () {
              if (isDownloading) return;
              if (event.canDownloadInBackground) {
                event.downloadInBackground(context);
              } else {
                event.saveFile(context);
              }
            },
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  CircleAvatar(
                    backgroundColor: textColor.withAlpha(32),
                    child: isDownloading
                        ? CircularProgressIndicator.adaptive(
                            value: downloadProgress / 100,
                          )
                        : Icon(
                            downloadError
                                ? Icons.error_outline
                                : downloadSuccess
                                ? Icons.file_download_done
                                : Icons.file_download_outlined,
                            color: textColor,
                          ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$sizeString | $filetype',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (fileDescription != null && !event.isRichFileDescription) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Linkify(
              text: fileDescription,
              textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
              style: TextStyle(
                color: textColor,
                fontSize:
                    AppSettings.fontSizeFactor.value *
                    AppSettings.messageFontSize.value,
              ),
              options: const LinkifyOptions(humanize: false),
              linkStyle: TextStyle(
                color: linkColor,
                fontSize:
                    AppSettings.fontSizeFactor.value *
                    AppSettings.messageFontSize.value,
                decoration: TextDecoration.underline,
                decorationColor: linkColor,
              ),
              onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
            ),
          ),
        ],
        if (fileDescription != null && event.isRichFileDescription) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: HtmlMessage(
              html: fileDescription,
              textColor: textColor,
              room: event.room,
              fontSize:
                  AppSettings.fontSizeFactor.value *
                  AppSettings.messageFontSize.value,
              linkStyle: TextStyle(
                color: linkColor,
                fontSize:
                    AppSettings.fontSizeFactor.value *
                    AppSettings.messageFontSize.value,
                decoration: TextDecoration.underline,
                decorationColor: linkColor,
              ),
              onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
              onCopy: () {
                Clipboard.setData(ClipboardData(text: event.body));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.of(context).copiedToClipboard)),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
