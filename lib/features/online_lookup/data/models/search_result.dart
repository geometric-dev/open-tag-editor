/// Unified search result from any online source.
class SearchResult {
  const SearchResult({
    required this.id,
    required this.title,
    this.artist,
    this.year,
    this.country,
    this.trackCount,
    required this.source,
  });

  /// Unique identifier (MusicBrainz release ID or Discogs release ID).
  final String id;

  /// Album/release title.
  final String title;

  /// Primary artist name.
  final String? artist;

  /// Release year.
  final String? year;

  /// Release country code.
  final String? country;

  /// Number of tracks on the release.
  final int? trackCount;

  /// Which service this result came from.
  final SearchSource source;
}

/// Online music database source.
enum SearchSource {
  /// MusicBrainz open music encyclopedia.
  musicBrainz,

  /// Discogs music database.
  discogs,
}

/// Unified track info from any source.
class TrackInfo {
  const TrackInfo({
    required this.title,
    required this.position,
    this.discNumber = 1,
    this.durationMs,
    this.artist,
  });

  /// Track title.
  final String title;

  /// Track position within the disc.
  final int position;

  /// Disc number (defaults to 1 for single-disc releases).
  final int discNumber;

  /// Track duration in milliseconds, if available.
  final int? durationMs;

  /// Track artist, if different from album artist.
  final String? artist;
}
