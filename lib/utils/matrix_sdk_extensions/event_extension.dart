import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:async/async.dart' as async;
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';

import 'package:extera_next/pages/download_manager/download_manager.dart';
import 'package:extera_next/utils/size_string.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import 'matrix_file_extension.dart';

extension LocalizedBody on Event {
  Future<async.Result<MatrixFile?>> _getFile(BuildContext context) =>
      showFutureLoadingDialog(
        context: context,
        future: downloadAndDecryptAttachment,
      );

  void saveFile(BuildContext context) async {
    final matrixFile = await _getFile(context);

    matrixFile.result?.save(context);
  }

  String getLink() {
    return "https://matrix.to/#/${room.canonicalAlias != '' ? room.canonicalAlias : roomId}/$eventId";
  }

  void downloadInBackground(BuildContext context) async {
    if (canDownloadInBackground) {
      final dmc = DownloadManager.of(context);
      final filename = content.tryGet<String>('filename') ?? body;
      dmc.download(
        context,
        "$filename.${roomId!.substring(1, 5)}.${eventId.substring(1, 5)}.${extensionFromMime(attachmentMimetype) ?? filename.split('.').last}",
        attachmentMxcUrl.toString(),
      );
    } else {
      throw Exception(
        "Cannot download in background $hasAttachment ${room.encrypted}",
      );
    }
  }

  void shareFile(BuildContext context) async {
    final matrixFile = await _getFile(context);
    inspect(matrixFile);

    matrixFile.result?.share(context);
  }

  bool get canDownloadInBackground => hasAttachment && !room.encrypted;

  bool get isAttachmentSmallEnough =>
      infoMap['size'] is int &&
      infoMap['size'] as int < room.client.database.maxFileSize;

  bool get isThumbnailSmallEnough =>
      thumbnailInfoMap['size'] is int &&
      thumbnailInfoMap['size'] as int < room.client.database.maxFileSize;

  bool get showThumbnail =>
      [
        MessageTypes.Image,
        MessageTypes.Sticker,
        MessageTypes.Video,
      ].contains(messageType) &&
      (kIsWeb ||
          isAttachmentSmallEnough ||
          isThumbnailSmallEnough ||
          (content['url'] is String));

  String? get sizeString => content
      .tryGetMap<String, dynamic>('info')
      ?.tryGet<int>('size')
      ?.sizeString;
}
