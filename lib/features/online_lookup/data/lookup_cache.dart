import 'models/search_result.dart';

/// In-memory session cache for lookup results.
///
/// Stores search results and track listings to avoid redundant API calls
/// within a session. All data is discarded when the app closes.
class LookupCache {
  final Map<String, List<SearchResult>> _searchResults = {};
  final Map<String, List<TrackInfo>> _trackListings = {};

  /// Stores search results keyed by a normalized query string.
  void cacheSearchResults(String cacheKey, List<SearchResult> results) {
    _searchResults[cacheKey] = results;
  }

  /// Retrieves cached search results, or null if not cached.
  List<SearchResult>? getSearchResults(String cacheKey) {
    return _searchResults[cacheKey];
  }

  /// Stores a track listing keyed by release ID.
  void cacheTrackListing(String releaseId, List<TrackInfo> tracks) {
    _trackListings[releaseId] = tracks;
  }

  /// Retrieves cached track listing, or null if not cached.
  List<TrackInfo>? getTrackListing(String releaseId) {
    return _trackListings[releaseId];
  }

  /// Clears all cached data.
  void clear() {
    _searchResults.clear();
    _trackListings.clear();
  }

  /// Generates a normalized cache key from search parameters.
  static String buildCacheKey({
    String? artist,
    String? album,
    String? year,
    Set<SearchSource>? sources,
  }) {
    final parts = <String>[
      'a:${(artist ?? '').toLowerCase().trim()}',
      'al:${(album ?? '').toLowerCase().trim()}',
      'y:${(year ?? '').trim()}',
      's:${(sources ?? {}).map((s) => s.name).toList()..sort()}',
    ];
    return parts.join('|');
  }
}
