import '../../../shared/models/audio_file.dart';
import 'lookup_cache.dart';
import 'models/search_result.dart';

/// Helper functions for the online lookup workflow.
class LookupHelpers {
  LookupHelpers._();

  /// Extracts pre-fill data (artist, album) from the first file in the list.
  ///
  /// Returns a record with artist and album strings (empty if not available).
  static ({String artist, String album}) extractPreFillData(
    List<AudioFile> files,
  ) {
    if (files.isEmpty) {
      return (artist: '', album: '');
    }
    final first = files.first;
    return (
      artist: first.tags['artist'] ?? '',
      album: first.tags['album'] ?? '',
    );
  }

  /// Merges search results from multiple sources into a single list.
  ///
  /// Preserves all results with their source indicators intact.
  /// Merges any number of per-source result lists, preserving order.
  static List<SearchResult> mergeAll(List<List<SearchResult>> batches) => [
    for (final batch in batches) ...batch,
  ];

  /// Builds a normalized cache key from search parameters.
  ///
  /// Delegates to [LookupCache.buildCacheKey] — this method exists for
  /// convenience so callers don't need to import the cache directly.
  static String buildCacheKey({
    String? artist,
    String? album,
    String? year,
    Set<SearchSource>? sources,
  }) {
    return LookupCache.buildCacheKey(
      artist: artist,
      album: album,
      year: year,
      sources: sources,
    );
  }
}
