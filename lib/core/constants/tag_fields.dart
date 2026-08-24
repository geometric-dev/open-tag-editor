/// Standard tag field names used across all formats.
enum TagField {
  title('Title'),
  artist('Artist'),
  albumArtist('Album Artist'),
  album('Album'),
  year('Year'),
  trackNumber('Track Number'),
  trackTotal('Track Total'),
  discNumber('Disc Number'),
  discTotal('Disc Total'),
  genre('Genre'),
  comment('Comment'),
  composer('Composer'),
  conductor('Conductor'),
  lyricist('Lyricist'),
  publisher('Publisher'),
  copyright('Copyright'),
  encodedBy('Encoded By'),
  bpm('BPM'),
  compilation('Compilation'),
  lyrics('Lyrics'),
  rating('Rating'),
  mood('Mood'),
  grouping('Grouping'),
  subtitle('Subtitle'),
  language('Language'),
  originalArtist('Original Artist'),
  remixer('Remixed By'),
  label('Label'),
  catalogNumber('Catalog #'),
  isrc('ISRC'),
  url('URL'),
  albumArt('Album Art');

  const TagField(this.displayName);

  final String displayName;
}
