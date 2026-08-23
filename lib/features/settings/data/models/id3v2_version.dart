/// Supported ID3v2 sub-versions.
enum Id3v2Version {
  v23('ID3v2.3', 3),
  v24('ID3v2.4', 4);

  const Id3v2Version(this.displayName, this.numericVersion);

  /// The human-readable label shown in the UI (e.g. "ID3v2.4").
  final String displayName;

  /// The numeric sub-version value (3 or 4).
  final int numericVersion;
}
