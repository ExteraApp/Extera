import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/utils/client_download_content_extension.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:extera_next/widgets/matrix.dart';

class MxcImage extends StatefulWidget {
  final Uri? uri;
  final Event? event;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool isThumbnail;
  final bool animated;
  final Duration retryDuration;
  final ThumbnailMethod thumbnailMethod;
  final Widget Function(BuildContext context)? placeholder;
  final String? cacheKey;
  final Client? client;
  final BorderRadius borderRadius;

  const MxcImage({
    this.uri,
    this.event,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.isThumbnail = true,
    this.animated = false,
    this.retryDuration = const Duration(seconds: 2),
    this.thumbnailMethod = ThumbnailMethod.scale,
    this.cacheKey,
    this.client,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  @override
  State<MxcImage> createState() => _MxcImageState();
}

class _MxcImageState extends State<MxcImage> {
  static const int _maxCacheSize = 100;
  static final LinkedHashMap<String, Uint8List> _imageDataCache =
      LinkedHashMap<String, Uint8List>();

  Uint8List? _currentData;
  bool _isLoading = false;

  // Track retry attempts to prevent infinite loops
  int _retryCount = 0;
  static const int _maxRetries = 3;

  String? get _effectiveCacheKey {
    if (widget.cacheKey != null) return widget.cacheKey;
    if (widget.event != null) {
      final suffix = widget.isThumbnail ? '_thumb' : '';
      return '${widget.event!.eventId}$suffix';
    }
    if (widget.uri != null) {
      final suffix = widget.isThumbnail ? '_thumb' : '';
      return '${widget.uri}$suffix';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentData = _getFromCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currentData == null && !_isLoading) {
      _load();
    }
  }

  @override
  void didUpdateWidget(MxcImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri ||
        oldWidget.event != widget.event ||
        oldWidget.cacheKey != widget.cacheKey) {
      _retryCount = 0;

      final cached = _getFromCache();
      if (cached != null) {
        setState(() {
          _currentData = cached;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentData = null;
          _isLoading = false;
        });
        _load();
      }
    }
  }

  Uint8List? _getFromCache() {
    final key = _effectiveCacheKey;
    if (key != null) {
      final data = _imageDataCache.remove(key);
      if (data != null) {
        _imageDataCache[key] = data;
      }
      return data;
    }
    return null;
  }

  void _saveToCache(Uint8List data) {
    final key = _effectiveCacheKey;
    if (key != null) {
      _imageDataCache.remove(key);
      _imageDataCache[key] = data;

      while (_imageDataCache.length > _maxCacheSize) {
        _imageDataCache.remove(_imageDataCache.keys.first);
      }
    }
  }

  Future<void> _load() async {
    if (_isLoading || !mounted) return;

    if (_retryCount >= _maxRetries) {
      Logs().w(
        'MxcImage failed to load after $_maxRetries attempts: ${widget.uri}',
      );
      return;
    }

    final originalUri = widget.uri;
    final originalEvent = widget.event;
    final originalCacheKey = widget.cacheKey;
    final originalIsThumbnail = widget.isThumbnail;
    final originalAnimated = widget.animated;
    final originalWidth = widget.width;
    final originalHeight = widget.height;

    setState(() {
      _isLoading = true;
    });

    try {
      final client =
          widget.client ??
          widget.event?.room.client ??
          Matrix.of(context).client;
      final uri = originalUri;
      final event = originalEvent;

      Uint8List? loadedBytes;

      if (uri != null) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final realWidth = originalWidth != null
            ? originalWidth * devicePixelRatio
            : null;
        final realHeight = originalHeight != null
            ? originalHeight * devicePixelRatio
            : null;

        loadedBytes = await client.downloadMxcCached(
          uri,
          width: realWidth,
          height: realHeight,
          thumbnailMethod: widget.thumbnailMethod,
          isThumbnail: originalIsThumbnail,
          animated: originalAnimated,
        );
      } else if (event != null) {
        final useThumbnail = originalIsThumbnail && event.hasThumbnail;
        if (!useThumbnail &&
            !{
              MessageTypes.Image,
              MessageTypes.Sticker,
            }.contains(event.messageType)) {
          throw Exception(
            'Event of type ${event.messageType} has no thumbnail!',
          );
        }
        final data = await event.downloadAndDecryptAttachment(
          getThumbnail: useThumbnail,
        );
        if (data.detectFileType is MatrixImageFile) {
          loadedBytes = data.bytes;
        }
      }

      if (!mounted) return;

      if (originalUri != widget.uri ||
          originalEvent != widget.event ||
          originalCacheKey != widget.cacheKey) {
        return;
      }

      if (loadedBytes != null && loadedBytes.isNotEmpty) {
        _saveToCache(loadedBytes);
        setState(() {
          _currentData = loadedBytes;
          _isLoading = false;
          _retryCount = 0;
        });
      } else {
        _scheduleRetry();
      }
    } on IOException catch (_) {
      _scheduleRetry();
    } catch (e, s) {
      Logs().d('Unexpected error loading mxc image', e, s);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scheduleRetry() {
    if (!mounted) return;

    setState(() => _isLoading = false);

    _retryCount++;

    // Exponential backoff: 2s, 4s, 8s, 16s...
    final delay = widget.retryDuration * pow(2, _retryCount - 1);

    Future.delayed(delay, () {
      if (mounted && _currentData == null) {
        _load();
      }
    });
  }

  Widget _buildPlaceholder(BuildContext context) =>
      widget.placeholder?.call(context) ??
      SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      );

  Widget _buildError(BuildContext context) =>
      widget.placeholder?.call(context) ??
      SizedBox(
        width: widget.width,
        height: widget.height,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Icon(
            Icons.broken_image_outlined,
            size: min(widget.height ?? 64, 64),
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final data = _currentData;

    if (data == null || data.isEmpty) {
      if (_retryCount >= _maxRetries && !_isLoading) {
        return _buildError(context);
      }

      return KeyedSubtree(
        key: const ValueKey('placeholder'),
        child: _buildPlaceholder(context),
      );
    }

    final repaintKey = ValueKey([
      _effectiveCacheKey ?? widget.uri,
      widget.width,
      widget.height,
      widget.isThumbnail,
      widget.fit,
    ]);

    final imageWidget = Image.memory(
      data,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: widget.isThumbnail
          ? FilterQuality.low
          : FilterQuality.medium,
      errorBuilder: (context, e, s) {
        Logs().d('Unable to render mxc image bytes', e, s);
        return _buildError(context);
      },
    );

    return RepaintBoundary(
      key: repaintKey,
      child: ClipRRect(borderRadius: widget.borderRadius, child: imageWidget),
    );
  }
}
