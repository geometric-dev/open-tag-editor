/// Determines which portion of the file path is used for mask matching.
enum PathScope {
  /// Match against filename only (no directory, no extension).
  filenameOnly('Filename only'),

  /// Match against relative path from loaded root folder (no extension).
  relativePath('Relative path'),

  /// Match against full absolute path (no extension).
  absolutePath('Absolute path');

  const PathScope(this.displayName);

  /// Human-readable display name for UI.
  final String displayName;
}
