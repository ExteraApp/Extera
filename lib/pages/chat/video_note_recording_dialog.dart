import 'dart:async';

import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:matrix/matrix.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';

/// A full-screen dialog for recording video notes, similar to Telegram.
/// Shows camera preview with controls overlay.
class VideoNoteRecordingDialog extends StatefulWidget {
  final Room room;
  final Future<void> Function(String path, int duration, String fileName)
  onVideoSend;

  const VideoNoteRecordingDialog({
    required this.room,
    required this.onVideoSend,
    super.key,
  });

  @override
  State<VideoNoteRecordingDialog> createState() =>
      _VideoNoteRecordingDialogState();
}

class _VideoNoteRecordingDialogState extends State<VideoNoteRecordingDialog>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 1; // Default front camera
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isSending = false;
  bool _isSwitchingCamera = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameraAndRecord();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (state == AppLifecycleState.inactive) {
        _cancel();
      }
    }
  }

  Future<void> _initCameraAndRecord() async {
    widget.room.client.getConfig();

    if (PlatformInfos.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt < 21) {
        if (mounted) {
          showOkAlertDialog(
            context: context,
            title: L10n.of(context).unsupportedAndroidVersion,
            message: L10n.of(context).unsupportedAndroidVersionLong,
            okLabel: L10n.of(context).close,
          );
          Navigator.of(context).pop();
        }
        return;
      }
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        Logs().w('No cameras available');
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (_currentCameraIndex >= _cameras!.length) {
        _currentCameraIndex = 0;
      }

      await _initCamera();
      await _startRecording();
    } catch (e, s) {
      Logs().w('Unable to start video note recording', e, s);
      if (mounted) {
        showOkAlertDialog(
          context: context,
          title: L10n.of(context).oopsSomethingWentWrong,
          message: e.toString(),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _initCamera() async {
    final camera = _cameras![_currentCameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    await _cameraController!.initialize();
    _isCameraInitialized = true;
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_isCameraInitialized) return;

    await WakelockPlus.enable();
    await _cameraController!.startVideoRecording();

    _fileName = 'video_note_${DateTime.now().millisecondsSinceEpoch}.mp4';
    _isRecording = true;
    _duration = Duration.zero;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _duration += const Duration(milliseconds: 100);
      });

      // Auto-stop at 60 seconds like Telegram
      if (_duration.inSeconds >= 60) {
        _sendVideo();
      }
    });

    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    if (_isSwitchingCamera) return;

    _isSwitchingCamera = true;
    setState(() {});

    try {
      final nextIndex = (_currentCameraIndex + 1) % _cameras!.length;
      final newCamera = _cameras![nextIndex];

      // Detach old controller from UI
      final oldController = _cameraController;
      _cameraController = null;
      _isCameraInitialized = false;
      if (mounted) setState(() {});

      // Stop recording and dispose old controller
      if (oldController != null) {
        if (oldController.value.isRecordingVideo) {
          try {
            await oldController.stopVideoRecording();
          } catch (_) {}
        }
        await oldController.dispose();
      }

      // Create new controller
      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await _cameraController!.initialize();
      _currentCameraIndex = nextIndex;
      _isCameraInitialized = true;
      if (mounted) setState(() {});

      // Restart recording and reset timer
      if (_isRecording) {
        await _cameraController!.startVideoRecording();
        _duration = Duration.zero;
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!mounted) return;
          setState(() {
            _duration += const Duration(milliseconds: 100);
          });
          if (_duration.inSeconds >= 60) {
            _sendVideo();
          }
        });
      }
    } catch (e, s) {
      Logs().w('Failed to switch camera', e, s);
    } finally {
      _isSwitchingCamera = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _sendVideo() async {
    if (_isSending) return;
    if (_cameraController == null ||
        !_cameraController!.value.isRecordingVideo) {
      return;
    }

    _isSending = true;
    _timer?.cancel();

    try {
      final xFile = await _cameraController!.stopVideoRecording();
      _isRecording = false;
      final capturedDuration = _duration.inMilliseconds;
      final capturedFileName = _fileName!;

      // Close dialog instantly
      if (mounted) Navigator.of(context).pop();

      // Compress and send in background
      var finalPath = xFile.path;
      try {
        final mediaInfo = await VideoCompress.compressVideo(
          xFile.path,
          quality: VideoQuality.MediumQuality,
          includeAudio: true,
        );
        if (mediaInfo?.file != null) {
          finalPath = mediaInfo!.file!.path;
        }
      } catch (e, s) {
        Logs().w('Video compression failed, using original', e, s);
      }

      await widget.onVideoSend(finalPath, capturedDuration, capturedFileName);
    } catch (e, s) {
      Logs().e('Unable to send video note', e, s);
      _isSending = false;
      if (mounted) setState(() {});
    }
  }

  void _cancel() {
    _timer?.cancel();
    WakelockPlus.disable();
    if (_cameraController != null) {
      if (_cameraController!.value.isRecordingVideo) {
        try {
          _cameraController!.stopVideoRecording();
        } catch (_) {}
      }
      _cameraController!.dispose();
      _cameraController = null;
    }
    _isCameraInitialized = false;
    _isRecording = false;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    WakelockPlus.disable();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time =
        '${_duration.inMinutes.toString().padLeft(2, '0')}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}';
    const maxSeconds = 60;
    final progress = _duration.inMilliseconds / (maxSeconds * 1000);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview - full screen
            if (_isCameraInitialized && _cameraController != null)
              Center(
                child: AspectRatio(
                  aspectRatio: 1 / (_cameraController!.value.aspectRatio),
                  child: CameraPreview(_cameraController!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),

            // Top bar with timer and progress
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Progress bar
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                    minHeight: 3,
                  ),
                  const SizedBox(height: 12),
                  // Timer chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRecording)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom controls - Material 3 buttons
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  IconButton.filledTonal(
                    onPressed: _cancel,
                    tooltip: L10n.of(context).cancel,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  // Switch camera button
                  IconButton.filledTonal(
                    onPressed: _isSwitchingCamera ? null : _switchCamera,
                    tooltip: L10n.of(context).switchCamera,
                    icon: _isSwitchingCamera
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cameraswitch_outlined),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  // Send button
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendVideo,
                    tooltip: L10n.of(context).sendVideoNote,
                    icon: _isSending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      minimumSize: const Size(64, 64),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
