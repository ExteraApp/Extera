import 'dart:typed_data';

import 'package:image/image.dart';

import 'package:extera_next/config/setting_keys.dart';

class ExifCleaner {
  static List<int> removeExifData(List<int> imageBytes) {
    // Decode the image (this strips EXIF data)
    final image = decodeImage(Uint8List.fromList(imageBytes));

    if (image == null) {
      if (AppSettings.doNotSendIfCantClean.value) {
        throw Exception('Failed to decode image');
      } else {
        return imageBytes;
      }
    }

    // Encode back to bytes without EXIF based on detected format
    List<int> cleanedBytes;

    image.exif.clear();

    if (_isJpeg(imageBytes)) {
      cleanedBytes = encodeJpg(image);
    } else if (_isPng(imageBytes)) {
      cleanedBytes = encodePng(image);
    } else if (_isGif(imageBytes)) {
      cleanedBytes = encodeGif(image);
    } else if (_isBmp(imageBytes)) {
      cleanedBytes = encodeBmp(image);
    } else if (_isTiff(imageBytes)) {
      // TIFF doesn't have a direct encoder in image package, convert to PNG
      cleanedBytes = encodeTiff(image);
    } else if (_isHeic(imageBytes)) {
      // HEIC format - convert to JPEG since image package doesn't have HEIC encoder
      cleanedBytes = encodeJpg(image);
    } else {
      // Default fallback - try to encode as PNG, then JPEG
      try {
        cleanedBytes = encodePng(image);
      } catch (e) {
        cleanedBytes = encodeJpg(image);
      }
    }

    return cleanedBytes;
  }

  static bool _isJpeg(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  }

  static bool _isPng(List<int> bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  static bool _isGif(List<int> bytes) {
    return bytes.length >= 6 &&
        bytes[0] == 0x47 && // G
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x38 && // 8
        (bytes[4] == 0x37 || bytes[4] == 0x39) && // 7 or 9
        bytes[5] == 0x61; // a
  }

  static bool _isBmp(List<int> bytes) {
    return bytes.length >= 2 &&
        bytes[0] == 0x42 && // B
        bytes[1] == 0x4D; // M
  }

  static bool _isTiff(List<int> bytes) {
    return bytes.length >= 4 &&
        ((bytes[0] == 0x49 &&
                bytes[1] == 0x49 &&
                bytes[2] == 0x2A &&
                bytes[3] == 0x00) || // Little Endian
            (bytes[0] == 0x4D &&
                bytes[1] == 0x4D &&
                bytes[2] == 0x00 &&
                bytes[3] == 0x2A)); // Big Endian
  }

  static bool _isWebP(List<int> bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50; // P
  }

  static bool _isHeic(List<int> bytes) {
    // HEIC files start with 'ftyp' at position 4
    if (bytes.length < 12) return false;

    // Check for 'ftyp' at position 4
    var hasFtyp =
        bytes[4] == 0x66 && // f
        bytes[5] == 0x74 && // t
        bytes[6] == 0x79 && // y
        bytes[7] == 0x70; // p

    if (!hasFtyp) return false;

    // Check for HEIC brand variants
    var heicBrands = <List<int>>[
      [0x68, 0x65, 0x69, 0x63], // heic
      [0x68, 0x65, 0x69, 0x78], // heix
      [0x68, 0x65, 0x76, 0x63], // hevc
      [0x68, 0x65, 0x76, 0x78], // hevx
      [0x6D, 0x69, 0x66, 0x31], // mif1
      [0x6D, 0x73, 0x66, 0x31], // msf1
    ];

    for (final brand in heicBrands) {
      if (bytes[8] == brand[0] &&
          bytes[9] == brand[1] &&
          bytes[10] == brand[2] &&
          bytes[11] == brand[3]) {
        return true;
      }
    }

    return false;
  }

  // Utility method to get image format name
  static String getImageFormat(List<int> bytes) {
    if (_isJpeg(bytes)) return 'JPEG';
    if (_isPng(bytes)) return 'PNG';
    if (_isGif(bytes)) return 'GIF';
    if (_isBmp(bytes)) return 'BMP';
    if (_isTiff(bytes)) return 'TIFF';
    if (_isWebP(bytes)) return 'WebP';
    if (_isHeic(bytes)) return 'HEIC';
    return 'Unknown';
  }
}
