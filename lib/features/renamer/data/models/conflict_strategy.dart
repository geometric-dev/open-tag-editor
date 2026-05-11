/// Strategy for resolving filename conflicts during rename.
enum ConflictStrategy {
  /// Skip files that would conflict.
  skip('Skip'),

  /// Overwrite existing files at the target path.
  overwrite('Overwrite'),

  /// Append a numeric suffix to make the filename unique.
  autoIncrement('Auto-increment');

  const ConflictStrategy(this.displayName);

  /// Human-readable display name for UI.
  final String displayName;
}
