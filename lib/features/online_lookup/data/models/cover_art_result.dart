import 'dart:typed_data';

/// Result of fetching album cover art from the Cover Art Archive.
class CoverArtResult {
  const CoverArtResult({required this.imageBytes, required this.mimeType});

  /// Raw image bytes.
  final Uint8List imageBytes;

  /// MIME type of the image (e.g., 'image/jpeg', 'image/png').
  final String mimeType;
}
