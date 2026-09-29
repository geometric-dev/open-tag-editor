import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_keys.dart';

import 'lookup_service_exception.dart';
import 'models/acoustid_models.dart';
import 'rate_limiter.dart';

/// Service for identifying audio files via the AcoustID API.
///
/// Submits Chromaprint fingerprints and returns matching MusicBrainz
/// recording IDs sorted by confidence.
class AcoustIDService {
  /// Creates an [AcoustIDService] with the given [rateLimiter].
  AcoustIDService({required this.rateLimiter});

  /// Rate limiter for AcoustID requests.
  final RateLimiter rateLimiter;

  /// AcoustID client API key (see [acoustidClientKey]).
  static const _apiKey = acoustidClientKey;

  static const _baseUrl = 'https://api.acoustid.org/v2/lookup';

  /// Looks up a fingerprint and returns matching recording IDs
  /// sorted by confidence score (highest first).
  ///
  /// Returns an empty list if no matches are found.
  Future<List<AcoustIDResult>> lookup({
    required String fingerprint,
    required int durationSeconds,
  }) async {
    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    request.body = Uri(
      queryParameters: {
        'client': _apiKey,
        'duration': durationSeconds.toString(),
        'fingerprint': fingerprint,
        'meta': 'recordings',
      },
    ).query;

    final response = await rateLimiter.send(request);

    if (response.statusCode != 200) {
      throw LookupServiceException(
        'AcoustID request failed',
        statusCode: response.statusCode,
      );
    }

    return _parseResponse(response.body);
  }

  List<AcoustIDResult> _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;

      if (results == null || results.isEmpty) return [];

      final acoustIdResults = <AcoustIDResult>[];

      for (final result in results) {
        final recordings = result['recordings'] as List<dynamic>?;
        if (recordings == null) continue;

        final score = (result['score'] as num?)?.toDouble() ?? 0.0;

        for (final recording in recordings) {
          final id = recording['id'] as String?;
          if (id == null) continue;

          final title = recording['title'] as String?;
          final artists = recording['artists'] as List<dynamic>?;
          final artist = artists != null && artists.isNotEmpty
              ? artists.first['name'] as String?
              : null;

          acoustIdResults.add(
            AcoustIDResult(
              recordingId: id,
              confidence: score,
              title: title,
              artist: artist,
            ),
          );
        }
      }

      // Sort by confidence descending
      acoustIdResults.sort((a, b) => b.confidence.compareTo(a.confidence));
      return acoustIdResults;
    } catch (_) {
      return [];
    }
  }
}
