import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/app_settings.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/events/html_message.dart';
import 'package:extera_next/pages/image_viewer/image_viewer.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/size_string.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/blur_hash.dart';
import 'package:extera_next/widgets/mxc_image.dart';

class EventVideoPlayer extends StatelessWidget {
  final Event event;
  final Timeline? timeline;
  final Color textColor;
  final Color linkColor;
  final bool loadThumbnail;
  final InlineSpan? trailingSpan;

  final bool ownMessage;
  final bool nextEventSameSender;
  final bool previousEventSameSender;

  const EventVideoPlayer(
    this.event,
    this.textColor,
    this.linkColor, {
    this.timeline,
    this.trailingSpan,
    this.loadThumbnail = false,
    this.ownMessage = false,
    this.nextEventSameSender = false,
    this.previousEventSameSender = false,
    super.key,
  });

  static const String fallbackBlurHash = 'L5H2EC=PM+yV0g-mq.wG9c010J}I';

  @override
  Widget build(BuildContext context) {
    final hardCorner = const Radius.circular(2);
    final roundedCorner = Radius.circular(AppConfig.borderRadius - 2);

    var borderRadius = BorderRadius.all(roundedCorner);

    final blurHash =
        (event.thumbnailInfoMap as Map<String, dynamic>).tryGet<String>(
          'xyz.amorgan.blurhash',
        ) ??
        fallbackBlurHash;
    final fileDescription = event.fileDescription == null
        ? null
        : AppSettings.renderHtml.value && event.isRichFileDescription
        ? event.fileDescription
        : event.fileDescription!
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;');

    final maxSize = 384.0;

    final infoMap = event.content.tryGetMap<String, Object?>('info');
    final w = infoMap?.tryGet<int>('w');
    final h = infoMap?.tryGet<int>('h');
    final hasDescription = event.fileDescription != null;
    const minBubbleWidth = 180.0;
    // const height = 300.0;
    var width = maxSize;
    if (w != null && h != null) {
      if (w > h) {
        width = maxSize;
      } else {
        width = max(32, maxSize * (w / h));
      }
    }

    final bubbleWidth = hasDescription ? max(minBubbleWidth, width) : width;

    var aspectRatio = 1.0;

    if (w != null && h != null && w > 0 && h > 0) {
      aspectRatio = w / h;
    }

    final sizeInt = infoMap?.tryGet<num>('size');

    final durationInt = infoMap?.tryGet<int>('duration');
    final duration = durationInt == null
        ? null
        : Duration(milliseconds: durationInt);

    if (ownMessage) {
      borderRadius = borderRadius.copyWith(
        topRight: nextEventSameSender ? hardCorner : roundedCorner,
        bottomRight: previousEventSameSender ? hardCorner : roundedCorner,
      );
    } else {
      borderRadius = borderRadius.copyWith(
        topLeft: nextEventSameSender ? hardCorner : roundedCorner,
        bottomLeft: previousEventSameSender ? hardCorner : roundedCorner,
      );
    }

    if (fileDescription != null) {
      borderRadius = borderRadius.copyWith(
        bottomLeft: hardCorner,
        bottomRight: hardCorner,
      );
    }

    if (event.inReplyToEventId(includingFallback: false) != null &&
        fileDescription != null) {
      borderRadius = borderRadius.copyWith(
        topLeft: hardCorner,
        topRight: hardCorner,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Padding(
          padding: const .all(2),
          child: Material(
            clipBehavior: .antiAlias,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleWidth),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  children: [
                    event.hasThumbnail && loadThumbnail
                        ? MxcImage(
                            event: event,
                            isThumbnail: true,
                            width: bubbleWidth,
                            fit: BoxFit.cover,
                            placeholder: (context) => LayoutBuilder(
                              builder: (context, constraints) => BlurHash(
                                blurhash: blurHash,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : BlurHash(
                            blurhash: blurHash,
                            width: bubbleWidth,
                            height: bubbleWidth / aspectRatio,
                            fit: BoxFit.cover,
                          ),
                    if (duration != null || sizeInt != null)
                      Positioned(
                        bottom: 3,
                        left: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const .symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              '${duration != null ? '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}' : ''}${duration != null && sizeInt != null ? ' • ' : ''}${sizeInt?.sizeString ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: IconButton.filledTonal(
                        onPressed: () => PlatformInfos.supportsVideoPlayer
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
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                        ),
                        icon: const Icon(Icons.play_arrow_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (fileDescription != null)
          SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  decoration: .none,
                ),
                trailingSpan: trailingSpan,
                selectable: true,
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
