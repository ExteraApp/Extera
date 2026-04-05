import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/image_viewer/video_player.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/hover_builder.dart';
import 'package:extera_next/widgets/mxc_image.dart';
import 'image_viewer.dart';

class ImageViewerView extends StatefulWidget {
  final ImageViewerController controller;

  const ImageViewerView(this.controller, {super.key});

  @override
  State<ImageViewerView> createState() => _ImageViewerViewState();
}

class _ImageViewerViewState extends State<ImageViewerView> {
  // Default physics allowing scroll
  ScrollPhysics _pageScrollPhysics = const BouncingScrollPhysics();

  /// Locks the PageView scroll.
  /// Used when the user starts pinching or is zoomed in.
  void _lockScroll(bool locked) {
    final newPhysics = locked
        ? const NeverScrollableScrollPhysics()
        : const BouncingScrollPhysics();

    if (_pageScrollPhysics.runtimeType != newPhysics.runtimeType) {
      setState(() {
        _pageScrollPhysics = newPhysics;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconButtonStyle = IconButton.styleFrom(
      backgroundColor: Colors.black.withAlpha(200),
      foregroundColor: Colors.white,
    );
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black.withAlpha(128),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            style: iconButtonStyle,
            icon: const Icon(Icons.close),
            onPressed: Navigator.of(context).pop,
            color: Colors.white,
            tooltip: L10n.of(context).close,
          ),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              style: iconButtonStyle,
              icon: const Icon(Icons.reply_outlined),
              onPressed: widget.controller.forwardAction,
              color: Colors.white,
              tooltip: L10n.of(context).share,
            ),
            const SizedBox(width: 8),
            IconButton(
              style: iconButtonStyle,
              icon: const Icon(Icons.download_outlined),
              onPressed: () => widget.controller.saveFileAction(context),
              color: Colors.white,
              tooltip: L10n.of(context).downloadFile,
            ),
            const SizedBox(width: 8),
            if (PlatformInfos.isMobile)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Builder(
                  builder: (context) => IconButton(
                    style: iconButtonStyle,
                    onPressed: () => widget.controller.shareFileAction(context),
                    tooltip: L10n.of(context).share,
                    color: Colors.white,
                    icon: Icon(Icons.adaptive.share_outlined),
                  ),
                ),
              ),
          ],
        ),
        body: HoverBuilder(
          builder: (context, hovered) => Stack(
            children: [
              KeyboardListener(
                focusNode: widget.controller.focusNode,
                onKeyEvent: widget.controller.onKeyEvent,
                child: PageView.builder(
                  scrollDirection: Axis.vertical,
                  // Apply the dynamic physics here
                  physics: _pageScrollPhysics,
                  controller: widget.controller.pageController,
                  itemCount: widget.controller.allEvents.length,
                  itemBuilder: (context, i) {
                    final event = widget.controller.allEvents[i];
                    switch (event.messageType) {
                      case MessageTypes.Video:
                        return Padding(
                          padding: const EdgeInsets.only(top: 52.0),
                          child: Center(
                            child: GestureDetector(
                              onTap: () {},
                              child: EventVideoPlayer(event, widget.controller),
                            ),
                          ),
                        );
                      case MessageTypes.Image:
                      case MessageTypes.Sticker:
                      default:
                        // Use the wrapper widget to handle zoom logic
                        return _ZoomableImage(
                          event: event,
                          controller: widget.controller,
                          onZoomStatusChanged: _lockScroll,
                        );
                    }
                  },
                ),
              ),
              if (hovered)
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.controller.canGoBack)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: IconButton(
                            style: iconButtonStyle,
                            tooltip: L10n.of(context).previous,
                            icon: const Icon(Icons.arrow_upward_outlined),
                            onPressed: widget.controller.prevImage,
                          ),
                        ),
                      if (widget.controller.canGoNext)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: IconButton(
                            style: iconButtonStyle,
                            tooltip: L10n.of(context).next,
                            icon: const Icon(Icons.arrow_downward_outlined),
                            onPressed: widget.controller.nextImage,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrapper widget to handle InteractiveViewer state and notify the parent
class _ZoomableImage extends StatefulWidget {
  final Event event;
  final ImageViewerController controller;
  final ValueChanged<bool> onZoomStatusChanged;

  const _ZoomableImage({
    required this.event,
    required this.controller,
    required this.onZoomStatusChanged,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  late final TransformationController _transformController;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 1.0,
      maxScale: 10.0,
      // When the user puts fingers on screen, disable PageView scroll
      onInteractionStart: (_) {
        widget.onZoomStatusChanged(true);
      },
      // When interaction ends, check if we are still zoomed in
      onInteractionEnd: (details) {
        widget.controller.onInteractionEnds(details);

        // Identity matrix means scale is 1.0 and offset is 0,0
        final isZoomed = _transformController.value.row0[0] != 1.0;
        if (!isZoomed) {
          widget.onZoomStatusChanged(false);
        }
      },
      child: Center(
        child: Hero(
          tag: widget.event.eventId,
          child: GestureDetector(
            onTap: () {},
            child: MxcImage(
              key: ValueKey(widget.event.eventId),
              event: widget.event,
              fit: BoxFit.contain,
              isThumbnail: false,
              animated: true,
            ),
          ),
        ),
      ),
    );
  }
}
