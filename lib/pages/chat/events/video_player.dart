import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/events/html_message.dart';
import 'package:extera_next/pages/image_viewer/image_viewer.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/blur_hash.dart';
import 'package:extera_next/widgets/mxc_image.dart';

class EventVideoPlayer extends StatelessWidget {
  final Event event;
  final Timeline? timeline;
  final Color textColor;
  final Color linkColor;
  final BorderRadius? borderRadius;

  const EventVideoPlayer(
    this.event,
    this.textColor,
    this.linkColor, {
    this.timeline,
    this.borderRadius,
    super.key,
  });

  static const String fallbackBlurHash = 'L5H2EC=PM+yV0g-mq.wG9c010J}I';

  @override
  Widget build(BuildContext context) {
    final supportsVideoPlayer = PlatformInfos.supportsVideoPlayer;
    final theme = Theme.of(context);

    var borderRadius =
        this.borderRadius ?? BorderRadius.circular(AppConfig.borderRadius);

    final blurHash =
        (event.thumbnailInfoMap as Map<String, dynamic>).tryGet<String>(
          'xyz.amorgan.blurhash',
        ) ??
        fallbackBlurHash;
    final fileDescription = event.fileDescription;
    final infoMap = event.content.tryGetMap<String, Object?>('info');
    final videoWidth = infoMap?.tryGet<int>('w') ?? 400;
    final videoHeight = infoMap?.tryGet<int>('h') ?? 300;
    const height = 300.0;
    final width = videoWidth * (height / videoHeight);

    final durationInt = infoMap?.tryGet<int>('duration');
    final duration = durationInt == null
        ? null
        : Duration(milliseconds: durationInt);

    if (fileDescription != null) {
      borderRadius = borderRadius.copyWith(
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      );
    }

    if (event.inReplyToEventId(includingFallback: false) != null &&
        fileDescription != null) {
      borderRadius = borderRadius.copyWith(
        topLeft: Radius.zero,
        topRight: Radius.zero,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Material(
          color: Colors.black,
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: theme.dividerColor),
          ),
          child: InkWell(
            onTap: () => supportsVideoPlayer
                ? showDialog(
                    context: context,
                    useRootNavigator: false,
                    builder: (_) => ImageViewer(
                      event,
                      timeline: timeline,
                      outerContext: context,
                    ),
                  )
                : event.saveFile(context),
            borderRadius: borderRadius,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  if (event.hasThumbnail)
                    MxcImage(
                      event: event,
                      uri: event.thumbnailMxcUrl,
                      isThumbnail: true,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      placeholder: (context) => BlurHash(
                        blurhash: blurHash,
                        width: width,
                        height: height,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    BlurHash(
                      blurhash: blurHash,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                    ),
                  Center(
                    child: CircleAvatar(
                      child: supportsVideoPlayer
                          ? const Icon(Icons.play_arrow_outlined)
                          : const Icon(Icons.file_download_outlined),
                    ),
                  ),
                  if (duration != null)
                    Positioned(
                      bottom: 8,
                      left: 16,
                      child: Text(
                        '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.white,
                          backgroundColor: Colors.black.withAlpha(32),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (fileDescription != null && !event.isRichFileDescription)
          SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          ),
        if (fileDescription != null && event.isRichFileDescription)
          SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          ),
      ],
    );
  }
}
