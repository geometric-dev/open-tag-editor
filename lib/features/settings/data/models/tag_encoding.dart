/// Supported text encodings for ID3v2 frames.
enum TagEncoding {
  utf8('UTF-8', 3),
  utf16('UTF-16', 1),
  latin1('Latin-1', 0);

  const TagEncoding(this.displayName, this.id3v2EncodingByte);

  /// The human-readable label shown in the UI (e.g. "UTF-8").
  final String displayName;

  /// The encoding byte value used in ID3v2 frame headers.
  final int id3v2EncodingByte;
}
