/// Supported tag variables for mask patterns.
enum TagVariable {
  artist('artist', 'Artist'),
  title('title', 'Title'),
  album('album', 'Album'),
  year('year', 'Year'),
  genre('genre', 'Genre'),
  track('track', 'Track Number'),
  totalTracks('totalTracks', 'Total Tracks'),
  disc('disc', 'Disc Number'),
  totalDiscs('totalDiscs', 'Total Discs'),
  albumArtist('albumartist', 'Album Artist'),
  comment('comment', 'Comment'),
  bpm('bpm', 'BPM'),
  composer('composer', 'Composer'),
  conductor('conductor', 'Conductor'),
  filename('filename', 'Original Filename'),
  ext('ext', 'File Extension');

  const TagVariable(this.maskName, this.displayName);

  /// The name as it appears in the mask (without %).
  final String maskName;

  /// Human-readable display name for UI.
  final String displayName;

  /// Looks up a [TagVariable] by its mask name. Returns null if not found.
  static TagVariable? fromMaskName(String name) {
    for (final v in values) {
      if (v.maskName == name) return v;
    }
    return null;
  }
}
