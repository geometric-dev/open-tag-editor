/// Case transformation options for resolved tag values.
enum CaseOption {
  /// Leave tag values unchanged.
  none('None'),

  /// Convert all characters to lowercase.
  lowercase('lowercase'),

  /// Convert all characters to uppercase.
  uppercase('UPPERCASE'),

  /// Capitalize the first letter of each word.
  capitalizeFirst('Capitalize First Letter'),

  /// Capitalize only the first letter of the first word.
  sentenceCase('Sentence case');

  const CaseOption(this.displayName);

  /// Human-readable display name for UI.
  final String displayName;
}
