import 'dart:convert';

import 'lookup_service_exception.dart';
import 'models/search_result.dart';
import 'rate_limiter.dart';

/// Service for searching releases on the Discogs API.
///
/// Requires a personal access token obtained from
/// https://www.discogs.com/settings/developers
class DiscogsService {
  /// Creates a [DiscogsService] with the given [rateLimiter] and [token].
  DiscogsService({
    required this.rateLimiter,
    required this.personalAccessToken,
  });

  /// Rate limiter for Discogs requests.
  final RateLimiter rateLimiter;

  /// Discogs personal access token.
  final String personalAccessToken;

  static const _baseUrl = 'https://api.discogs.com';
  static const _userAgent = 'OpenTagEditor/0.1.0';

  Map<String, String> get _headers => {
        'Authorization': 'Discogs token=$personalAccessToken',
        'User-Agent': _userAgent,
      };

  /// Searches for releases matching the query.
  ///
  /// Returns an empty list on failure or no results.
  Future<List<SearchResult>> searchReleases({
    String? artist,
    String? album,
    int? year,
    int page = 1,
    int perPage = 25,
  }) async {
    final queryParts = <String>[];
    if (artist != null && artist.isNotEmpty) queryParts.add(artist);
    if (album != null && album.isNotEmpty) queryParts.add(album);

    final params = <String, String>{
      'type': 'release',
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (queryParts.isNotEmpty) params['q'] = queryParts.join(' ');
    if (year != null) params['year'] = year.toString();

    final url = Uri.parse('$_baseUrl/database/search').replace(
      queryParameters: params,
    );

    try {
      final response = await rateLimiter.get(url, headers: _headers);

      if (response.statusCode != 200) {
        throw LookupServiceException(
          'Discogs request failed',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;

      if (results == null) return [];

      return results.map((r) {
        final title = r['title'] as String? ?? '';
        // Discogs title format is "Artist - Album"
        final parts = title.split(' - ');
        final resultArtist = parts.length > 1 ? parts.first : null;
        final resultAlbum =
            parts.length > 1 ? parts.sublist(1).join(' - ') : title;

        return SearchResult(
          id: (r['id'] as int).toString(),
          title: resultAlbum,
          artist: resultArtist,
          year: r['year'] as String?,
          country: r['country'] as String?,
          trackCount: null,
          source: SearchSource.discogs,
        );
      }).toList();
    } on LookupServiceException {
      rethrow;
    } catch (e) {
      throw LookupServiceException('Discogs request failed: $e');
    }
  }

  /// Fetches the full track listing for a Discogs release.
  ///
  /// Returns an empty list on failure.
  Future<List<TrackInfo>> getReleaseTracks(int releaseId) async {
    final url = Uri.parse('$_baseUrl/releases/$releaseId');

    try {
      final response = await rateLimiter.get(url, headers: _headers);

      if (response.statusCode != 200) {
        throw LookupServiceException(
          'Discogs request failed',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tracklist = json['tracklist'] as List<dynamic>?;

      if (tracklist == null) return [];

      final tracks = <TrackInfo>[];
      var position = 1;
      var discNumber = 1;

      for (final track in tracklist) {
        final type = track['type_'] as String?;
        if (type == 'heading') {
          // Disc separator — increment disc number and reset position
          discNumber++;
          position = 1;
          continue;
        }

        final title = track['title'] as String? ?? '';
        final durationStr = track['duration'] as String?;
        final durationMs = _parseDuration(durationStr);

        tracks.add(
          TrackInfo(
            title: title,
            position: position,
            discNumber: discNumber,
            durationMs: durationMs,
            artist: track['artists'] != null
                ? (track['artists'] as List).map((a) => a['name']).join(', ')
                : null,
          ),
        );
        position++;
      }

      return tracks;
    } on LookupServiceException {
      rethrow;
    } catch (e) {
      throw LookupServiceException('Discogs request failed: $e');
    }
  }

  /// Parses Discogs duration format "M:SS" or "MM:SS" to milliseconds.
  int? _parseDuration(String? duration) {
    if (duration == null || duration.isEmpty) return null;
    final parts = duration.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    return (minutes * 60 + seconds) * 1000;
  }
}
