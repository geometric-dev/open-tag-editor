import 'dart:typed_data';

import 'models/cover_art_result.dart';
import 'rate_limiter.dart';

/// Fetches album artwork from the Cover Art Archive.
///
/// The Cover Art Archive is a free service linked to MusicBrainz releases.
/// No authentication required.
class CoverArtService {
  /// Creates a [CoverArtService] with the given [rateLimiter].
  CoverArtService({required this.rateLimiter});

  /// Rate limiter for Cover Art Archive requests.
  final RateLimiter rateLimiter;

  static const _baseUrl = 'https://coverartarchive.org';

  /// Fetches the front cover image for a MusicBrainz release.
  ///
  /// Returns [CoverArtResult] with image bytes and MIME type,
  /// or null if no artwork is available (404).
  Future<CoverArtResult?> getFrontCover(String mbReleaseId) async {
    final url = Uri.parse('$_baseUrl/release/$mbReleaseId/front');

    try {
      final response = await rateLimiter.get(url);

      if (response.statusCode == 404) {
        return null;
      }

      if (response.statusCode != 200) {
        return null;
      }

      final mimeType = response.headers['content-type'] ?? 'image/jpeg';

      return CoverArtResult(
        imageBytes: Uint8List.fromList(response.bodyBytes),
        mimeType: mimeType,
      );
    } catch (_) {
      return null;
    }
  }
}
