/// A release result from the Discogs API.
class DiscogsRelease {
  const DiscogsRelease({
    required this.id,
    required this.title,
    this.artist,
    this.year,
    this.country,
    this.trackCount,
  });

  /// Discogs release ID.
  final int id;

  /// Release title.
  final String title;

  /// Primary artist name.
  final String? artist;

  /// Release year.
  final String? year;

  /// Release country.
  final String? country;

  /// Number of tracks.
  final int? trackCount;
}

/// A track from a Discogs release.
class DiscogsTrack {
  const DiscogsTrack({
    required this.title,
    required this.position,
    this.duration,
    this.artist,
  });

  /// Track title.
  final String title;

  /// Track position (1-based).
  final int position;

  /// Duration in "M:SS" format from Discogs, if available.
  final String? duration;

  /// Track artist, if different from release artist.
  final String? artist;
}
