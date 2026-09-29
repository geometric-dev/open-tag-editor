import 'dart:convert';

import 'lookup_service_exception.dart';
import 'models/search_result.dart';
import 'rate_limiter.dart';

/// Service for searching releases and recordings on MusicBrainz.
///
/// Uses the MusicBrainz JSON Web Service v2.
/// Rate limited to 1 request per second (enforced by [RateLimiter]).
class MusicBrainzService {
  /// Creates a [MusicBrainzService] with the given [rateLimiter].
  MusicBrainzService({required this.rateLimiter});

  /// Rate limiter for MusicBrainz requests.
  final RateLimiter rateLimiter;

  static const _baseUrl = 'https://musicbrainz.org/ws/2';
  static const _userAgent =
      'OpenTagEditor/0.1.0 (https://github.com/open-tag-editor)';

  Map<String, String> get _headers => {
    'User-Agent': _userAgent,
    'Accept': 'application/json',
  };

  /// Searches for releases matching the given criteria.
  ///
  /// Returns an empty list on failure or no results.
  Future<List<SearchResult>> searchReleases({
    String? artist,
    String? album,
    String? year,
    int limit = 25,
    int offset = 0,
  }) async {
    final query = _buildQuery(artist: artist, album: album, year: year);
    if (query.isEmpty) return [];

    final url = Uri.parse('$_baseUrl/release').replace(
      queryParameters: {
        'query': query,
        'limit': limit.toString(),
        'offset': offset.toString(),
        'fmt': 'json',
      },
    );

    try {
      final response = await rateLimiter.get(url, headers: _headers);

      if (response.statusCode != 200) {
        throw LookupServiceException(
          'MusicBrainz request failed',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final releases = json['releases'] as List<dynamic>?;

      if (releases == null) return [];

      return releases.map((r) {
        final artistCredit = r['artist-credit'] as List<dynamic>?;
        final artistName = artistCredit != null && artistCredit.isNotEmpty
            ? artistCredit.first['name'] as String?
            : null;

        final date = r['date'] as String?;
        final releaseYear = date != null && date.length >= 4
            ? date.substring(0, 4)
            : null;

        final media = r['media'] as List<dynamic>?;
        final trackCount = media?.fold<int>(
          0,
          (sum, m) => sum + ((m['track-count'] as int?) ?? 0),
        );

        return SearchResult(
          id: r['id'] as String,
          title: r['title'] as String? ?? '',
          artist: artistName,
          year: releaseYear,
          country: r['country'] as String?,
          trackCount: trackCount,
          source: SearchSource.musicBrainz,
        );
      }).toList();
    } on LookupServiceException {
      rethrow;
    } catch (e) {
      throw LookupServiceException('MusicBrainz request failed: $e');
    }
  }

  /// Fetches the full track listing for a MusicBrainz release.
  ///
  /// Returns an empty list on failure.
  Future<List<TrackInfo>> getReleaseTracks(String releaseId) async {
    final url = Uri.parse('$_baseUrl/release/$releaseId').replace(
      queryParameters: {'inc': 'recordings+artist-credits', 'fmt': 'json'},
    );

    try {
      final response = await rateLimiter.get(url, headers: _headers);

      if (response.statusCode != 200) {
        throw LookupServiceException(
          'MusicBrainz request failed',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final media = json['media'] as List<dynamic>?;

      if (media == null) return [];

      final tracks = <TrackInfo>[];

      for (var discIndex = 0; discIndex < media.length; discIndex++) {
        final disc = media[discIndex] as Map<String, dynamic>;
        final discTracks = disc['tracks'] as List<dynamic>?;
        if (discTracks == null) continue;

        for (final track in discTracks) {
          final recording = track['recording'] as Map<String, dynamic>?;
          final title =
              track['title'] as String? ?? recording?['title'] as String? ?? '';
          final position = track['position'] as int? ?? 0;
          final length =
              track['length'] as int? ?? recording?['length'] as int?;

          // Track artist if different from release artist
          final artistCredit = track['artist-credit'] as List<dynamic>?;
          final trackArtist = artistCredit != null && artistCredit.isNotEmpty
              ? artistCredit.first['name'] as String?
              : null;

          tracks.add(
            TrackInfo(
              title: title,
              position: position,
              discNumber: discIndex + 1,
              durationMs: length,
              artist: trackArtist,
            ),
          );
        }
      }

      return tracks;
    } on LookupServiceException {
      rethrow;
    } catch (e) {
      throw LookupServiceException('MusicBrainz request failed: $e');
    }
  }

  /// Builds a MusicBrainz Lucene query string from search parameters.
  String _buildQuery({String? artist, String? album, String? year}) {
    final parts = <String>[];
    if (artist != null && artist.isNotEmpty) {
      parts.add('artist:"$artist"');
    }
    if (album != null && album.isNotEmpty) {
      parts.add('release:"$album"');
    }
    if (year != null && year.isNotEmpty) {
      parts.add('date:$year');
    }
    return parts.join(' AND ');
  }
}
