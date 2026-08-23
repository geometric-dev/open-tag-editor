/// Extracts matching signals from audio filenames.
///
/// Provides static utilities for parsing track numbers and titles
/// from audio filenames to support multi-signal track matching.
class FilenameParser {
  FilenameParser._();

  /// Pattern matching leading digits followed by a non-digit separator.
  ///
  /// Captures one or more leading digits, then expects a separator character
  /// (space, underscore, hyphen, or dot) before the rest of the filename.
  static final _leadingDigitsPattern = RegExp(r'^(\d+)[\s_\-.]');

  /// Pattern matching a file extension at the end of a filename.
  static final _extensionPattern = RegExp(r'\.[^.]+$');

  /// Pattern matching leading digits + separator prefix for removal.
  static final _leadingPrefixPattern = RegExp(r'^\d+[\s_\-.]');

  /// Pattern matching separator characters to normalise to spaces.
  static final _separatorPattern = RegExp(r'[_\-.]');

  /// Extracts a leading track number from a filename.
  ///
  /// Parses digits before the first non-digit separator (space, underscore,
  /// hyphen, dot). Returns null if no leading digits found.
  ///
  /// Examples:
  /// - `"01_Take_Me_Away.mp3"` → `1`
  /// - `"Take Me Away.mp3"` → `null`
  /// - `"1.mp3"` → `1`
  static int? extractTrackNumber(String filename) {
    final match = _leadingDigitsPattern.firstMatch(filename);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Extracts a title from a filename by removing extension, leading track
  /// number prefix, and normalising separators to spaces.
  ///
  /// Steps:
  /// 1. Remove file extension
  /// 2. Remove leading digits + separator
  /// 3. Replace underscores, hyphens, dots with spaces
  /// 4. Trim whitespace
  ///
  /// Example: `"01_Take_Me_Away.mp3"` → `"Take Me Away"`
  static String extractTitle(String filename) {
    // 1. Remove file extension
    var result = filename.replaceFirst(_extensionPattern, '');

    // 2. Remove leading digits + separator
    result = result.replaceFirst(_leadingPrefixPattern, '');

    // 3. Replace underscores, hyphens, dots with spaces
    result = result.replaceAll(_separatorPattern, ' ');

    // 4. Trim whitespace
    return result.trim();
  }
}
