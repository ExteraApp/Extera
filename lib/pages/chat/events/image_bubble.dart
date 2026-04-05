import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat/events/html_message.dart';
import 'package:extera_next/pages/image_viewer/image_viewer.dart';
import 'package:extera_next/utils/url_launcher.dart';
import 'package:extera_next/widgets/mxc_image.dart';
import '../../../widgets/blur_hash.dart';

class ImageBubble extends StatelessWidget {
  final Event event;
  final bool tapToView;
  final BoxFit fit;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? linkColor;
  final bool thumbnailOnly;
  final bool animated;
  final double width;
  final double? imageWidth;
  final double height;
  final void Function()? onTap;
  final BorderRadius? borderRadius;
  final Timeline? timeline;

  const ImageBubble(
    this.event, {
    this.tapToView = true,
    this.backgroundColor,
    this.fit = BoxFit.contain,
    this.thumbnailOnly = true,
    this.width = 400,
    this.imageWidth,
    this.height = 300,
    this.animated = false,
    this.onTap,
    this.borderRadius,
    this.timeline,
    this.textColor,
    this.linkColor,
    super.key,
  });

  double get _effectiveImageWidth => imageWidth ?? width;

  double get _aspectRatio {
    // Get image dimensions from event metadata
    final infoMap = event.infoMap;
    final imageWidth = infoMap['w'] as int?;
    final imageHeight = infoMap['h'] as int?;

    if (imageWidth != null &&
        imageHeight != null &&
        imageWidth > 0 &&
        imageHeight > 0) {
      // Return aspect ratio (width / height)
      return imageWidth / imageHeight;
    }

    // Fallback to square aspect ratio if metadata is not available
    return 1.0;
  }

  Widget _buildPlaceholder(BuildContext context) {
    final blurHashString = event.infoMap['xyz.amorgan.blurhash'] is String
        ? event.infoMap['xyz.amorgan.blurhash'] as String
        : 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
    return LayoutBuilder(
      builder: (context, constraints) {
        return BlurHash(
          blurhash: blurHashString,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          fit: fit,
        );
      },
    );
  }

  void _onTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (!tapToView) return;
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) =>
          ImageViewer(event, timeline: timeline, outerContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var borderRadius =
        this.borderRadius ?? BorderRadius.circular(AppConfig.borderRadius);

    final fileDescription = event.fileDescription;
    final textColor = this.textColor;

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
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: event.messageType == MessageTypes.Sticker
                    ? Colors.transparent
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: borderRadius,
              ),
              clipBehavior: Clip.hardEdge,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onTap(context),
                  child: Hero(
                    tag: event.eventId,
                    child: MxcImage(
                      event: event,
                      width: _effectiveImageWidth,
                      fit: fit,
                      animated: animated,
                      isThumbnail: thumbnailOnly,
                      placeholder: event.messageType == MessageTypes.Sticker
                          ? null
                          : _buildPlaceholder,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (fileDescription != null &&
            textColor != null &&
            !event.isRichFileDescription)
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
        if (fileDescription != null &&
            textColor != null &&
            event.isRichFileDescription)
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
