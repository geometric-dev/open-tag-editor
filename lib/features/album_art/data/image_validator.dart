import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Maximum image size before showing a warning (5 MB).
const int maxImageSizeBytes = 5 * 1024 * 1024;

/// Supported image MIME types for album art.
const Set<String> supportedImageMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/bmp',
  'image/gif',
  'image/webp',
};

/// Returns true if [mimeType] is a supported image MIME type for album art.
///
/// Comparison is case-insensitive.
bool isValidImageMimeType(String mimeType) {
  return supportedImageMimeTypes.contains(mimeType.toLowerCase());
}

/// Detects the MIME type of an image from its magic bytes.
///
/// Returns the MIME type string if recognized, or null if the bytes
/// do not match any supported image format.
String? detectMimeType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }

  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }

  if (bytes.length >= 4 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return 'image/gif';
  }

  if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return 'image/bmp';
  }

  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }

  return null;
}

/// Returns true if [bytes] exceeds the maximum recommended image size (5 MB).
bool exceedsSizeThreshold(int bytes) {
  return bytes > maxImageSizeBytes;
}

/// Decodes image [bytes] and returns the dimensions as a record.
///
/// Returns null if the image cannot be decoded.
({int width, int height})? getImageDimensions(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    return (width: image.width, height: image.height);
  } catch (_) {
    return null;
  }
}
