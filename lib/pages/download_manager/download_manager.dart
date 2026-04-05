import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:extera_next/utils/downloads_directory.dart';
import 'package:extera_next/widgets/matrix.dart';

sealed class DownloadEvent {
  final String downloadName;
  final String downloadUrl;
  final DateTime timestamp;

  DownloadEvent({
    required this.downloadName,
    required this.downloadUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class DownloadStartEvent extends DownloadEvent {
  final int totalBytes;

  DownloadStartEvent({
    required super.downloadName,
    required super.downloadUrl,
    required this.totalBytes,
  });

  @override
  String toString() =>
      'DownloadStartEvent(name: $downloadName, url: $downloadUrl, totalBytes: $totalBytes)';
}

class DownloadProgressEvent extends DownloadEvent {
  final int receivedBytes;
  final int totalBytes;
  final double progress;

  DownloadProgressEvent({
    required super.downloadName,
    required super.downloadUrl,
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
  });

  @override
  String toString() =>
      'DownloadProgressEvent(name: $downloadName, url: $downloadUrl, progress: ${progress.toStringAsFixed(1)}%, received: $receivedBytes/$totalBytes)';
}

class DownloadEndEvent extends DownloadEvent {
  final bool success;
  final String? filePath;
  final Object? error;

  DownloadEndEvent({
    required super.downloadName,
    required super.downloadUrl,
    this.success = true,
    this.filePath,
    this.error,
  });

  @override
  String toString() =>
      'DownloadEndEvent(name: $downloadName, url: $downloadUrl, success: $success, error: $error)';
}

class Download {
  final String url;
  final String name;
  final DownloadManagerState manager;
  late Future<Response<dynamic>> response;
  int receivedBytes = 0;
  int totalBytes = 1;
  double progress = 0;
  late String httpUrl;
  late String downloadPath;
  late CancelToken ct;
  bool _isCompleted = false;

  Download(this.manager, this.url, this.name);

  void start(BuildContext context) async {
    try {
      final mx = Matrix.of(context).client;
      downloadPath = getDownloadsDirectory();

      httpUrl = (await Uri.parse(url).getDownloadUri(mx)).toString();

      final dio = Dio();
      ct = CancelToken();

      response = dio.download(
        httpUrl,
        "$downloadPath/$name",
        onReceiveProgress: (received, total) {
          receivedBytes = received;
          totalBytes = total;
          progress = (receivedBytes / totalBytes) * 100;

          if (received == 0 || totalBytes == total && receivedBytes == 0) {
            manager._emitEvent(
              DownloadStartEvent(
                downloadName: name,
                downloadUrl: url,
                totalBytes: totalBytes,
              ),
            );
          }

          manager._emitEvent(
            DownloadProgressEvent(
              downloadName: name,
              downloadUrl: url,
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
              progress: progress,
            ),
          );

          Logs().w("Download progress: $progress%");
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'authorization': "Bearer ${mx.accessToken}"},
        ),
        cancelToken: ct,
      );

      await response;

      if (!_isCompleted) {
        _isCompleted = true;
        manager._emitEvent(
          DownloadEndEvent(
            downloadName: name,
            downloadUrl: url,
            success: true,
            filePath: "$downloadPath/$name",
          ),
        );
        manager._removeDownload(this);
        Logs().w("Download completed and saved to $downloadPath/$name");
      }
    } catch (e) {
      if (!_isCompleted) {
        _isCompleted = true;
        Logs().w("Error during download: $e");
        manager._emitEvent(
          DownloadEndEvent(
            downloadName: name,
            downloadUrl: url,
            success: false,
            error: e,
          ),
        );
        manager._removeDownload(this);
      }
    }
  }

  void cancel() {
    if (!_isCompleted) {
      _isCompleted = true;
      ct.cancel();
      manager._emitEvent(
        DownloadEndEvent(
          downloadName: name,
          downloadUrl: url,
          success: false,
          error: 'Cancelled by user',
        ),
      );
      manager._removeDownload(this);
    }
  }
}

/// Wrapper class for managing event subscriptions with easy cancellation
class DownloadEventSubscription {
  final StreamSubscription<DownloadEvent> _subscription;
  final DownloadManagerState _manager;
  bool _isCancelled = false;

  DownloadEventSubscription(this._subscription, this._manager);

  bool get isCancelled => _isCancelled;

  void pause() => _subscription.pause();

  void resume() => _subscription.resume();

  bool get isPaused => _subscription.isPaused;

  Future<void> cancel() async {
    if (!_isCancelled) {
      _isCancelled = true;
      await _subscription.cancel();
      _manager._removeSubscription(this);
    }
  }
}

class DownloadManagerState extends State<DownloadManager>
    with WidgetsBindingObserver {
  final List<Download> downloads = [];
  final Set<DownloadEventSubscription> _subscriptions = {};

  final StreamController<DownloadEvent> _eventStreamController =
      StreamController<DownloadEvent>.broadcast();

  Stream<DownloadEvent> get eventStream => _eventStreamController.stream;

  int get activeSubscriptionCount => _subscriptions.length;

  void _emitEvent(DownloadEvent event) {
    if (!_eventStreamController.isClosed) {
      _eventStreamController.add(event);
    }
  }

  void _removeDownload(Download download) {
    downloads.remove(download);
  }

  void _removeSubscription(DownloadEventSubscription subscription) {
    _subscriptions.remove(subscription);
  }

  void download(BuildContext context, String name, String url) {
    final dl = Download(this, url, name);
    downloads.add(dl);
    dl.start(context);
  }

  Download? getDownloadByName(String name) {
    try {
      return downloads.firstWhere((d) => d.name == name);
    } catch (_) {
      return null;
    }
  }

  Download? getDownloadByUrl(String url) {
    try {
      return downloads.firstWhere((d) => d.url == url);
    } catch (_) {
      return null;
    }
  }

  /// Subscribe to download events. Returns a [DownloadEventSubscription]
  /// that can be cancelled by calling [DownloadEventSubscription.cancel].
  DownloadEventSubscription onEvent(
    void Function(DownloadEvent event) onData, {
    void Function(Object error)? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) {
    final streamSubscription = _eventStreamController.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );

    final subscription = DownloadEventSubscription(streamSubscription, this);
    _subscriptions.add(subscription);

    return subscription;
  }

  /// Subscribe to events for a specific download by URL only
  DownloadEventSubscription onEventFor(
    String downloadUrl,
    void Function(DownloadEvent event) onData, {
    void Function(Object error)? onError,
    void Function()? onDone,
    bool cancelOnError = false,
    bool autoDisposeOnEnd = true,
  }) {
    late DownloadEventSubscription subscription;

    subscription = onEvent(
      (event) {
        if (event.downloadUrl == downloadUrl) {
          onData(event);

          // Auto-cancel when download ends
          if (autoDisposeOnEnd && event is DownloadEndEvent) {
            subscription.cancel();
          }
        }
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );

    return subscription;
  }

  /// Cancel all active subscriptions
  Future<void> cancelAllSubscriptions() async {
    final subscriptionsCopy = Set<DownloadEventSubscription>.from(
      _subscriptions,
    );
    for (final subscription in subscriptionsCopy) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    super.dispose();
    cancelAllSubscriptions();
    for (final download in downloads.toList()) {
      download.cancel();
    }
    _eventStreamController.close();
  }

  @override
  Widget build(BuildContext context) {
    return Provider(create: (_) => this, child: widget.child);
  }
}

class DownloadManager extends StatefulWidget {
  final Widget child;

  const DownloadManager({required this.child, super.key});

  @override
  DownloadManagerState createState() => DownloadManagerState();

  /// Returns the (nearest) Client instance of your application.
  static DownloadManagerState of(BuildContext context) =>
      Provider.of<DownloadManagerState>(context, listen: false);
}
