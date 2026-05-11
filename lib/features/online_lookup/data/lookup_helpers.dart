import '../../../shared/models/audio_file.dart';
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
  /// Results are interleaved: MusicBrainz first, then Discogs.
  static List<SearchResult> mergeResults(
    List<SearchResult> musicBrainzResults,
    List<SearchResult> discogsResults,
  ) {
    return [...musicBrainzResults, ...discogsResults];
  }

  /// Groups a list of tracks by disc number.
  ///
  /// Returns a map where keys are disc numbers (1-based) and values
  /// are the tracks for that disc, sorted by position.
  static Map<int, List<TrackInfo>> groupTracksByDisc(List<TrackInfo> tracks) {
    final groups = <int, List<TrackInfo>>{};

    for (final track in tracks) {
      groups.putIfAbsent(track.discNumber, () => []).add(track);
    }

    // Sort tracks within each disc by position
    for (final tracks in groups.values) {
      tracks.sort((a, b) => a.position.compareTo(b.position));
    }

    // Return sorted by disc number
    return Map.fromEntries(
      groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// Builds a normalized cache key from search parameters.
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
