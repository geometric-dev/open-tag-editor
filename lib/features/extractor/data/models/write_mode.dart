/// Controls how extracted values interact with existing tag values.
enum WriteMode {
  /// Replace existing tag values with extracted values.
  overwriteExisting('Overwrite existing tags'),

  /// Only write to fields that are currently empty.
  fillEmptyOnly('Only fill empty fields');

  const WriteMode(this.displayName);

  /// Human-readable display name for UI.
  final String displayName;
}
