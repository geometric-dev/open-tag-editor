import '../../features/settings/data/models/tag_encoding.dart';
import '../../features/settings/data/models/tag_write_options.dart';
import 'taglib/taglib_types.dart';

/// Severity level for a tag field validation issue.
enum TagFieldSeverity {
  /// Advisory warning — the value can be written but may be lossy.
  warning,

  /// Error — the value cannot be represented in the target format/encoding.
  error,
}

/// A single validation issue found for a tag field value.
class TagFieldIssue {
  /// Creates a [TagFieldIssue].
  const TagFieldIssue({
    required this.severity,
    required this.message,
    required this.field,
  });

  /// The severity of this issue.
  final TagFieldSeverity severity;

  /// Human-readable description of the problem.
  final String message;

  /// The field name this issue applies to.
  final String field;
}

/// Validates tag field values against format constraints and write settings.
///
/// This is a pure-function validator with no side effects. It checks values
/// against the target format's limits and the user's encoding/version settings,
/// returning a list of issues (warnings or errors) for the given field.
class TagFieldValidator {
  const TagFieldValidator._();

  /// Maximum practical field length to prevent accidental paste-bombs.
  static const int maxFieldLength = 10000;

  /// Maximum field length for ID3v1 text fields.
  static const int id3v1MaxLength = 30;

  /// Maximum field length for ID3v1 year field.
  static const int id3v1YearMaxLength = 4;

  /// Fields that should contain only numeric values.
  static const Set<String> numericFields = {
    'year',
    'trackNumber',
    'trackTotal',
    'discNumber',
    'discTotal',
    'bpm',
  };

  /// Validates a single field value against the current write settings.
  ///
  /// Returns a list of [TagFieldIssue]s found. An empty list means the
  /// value is valid for the given configuration.
  ///
  /// Parameters:
  /// - [field]: The app field name (e.g., 'title', 'artist', 'year').
  /// - [value]: The current text value to validate.
  /// - [options]: The current tag write options (encoding, version, ID3v1).
  /// - [tagFormat]: The detected tag format of the file (nullable).
  static List<TagFieldIssue> validate({
    required String field,
    required String value,
    required TagWriteOptions options,
    TagFormat? tagFormat,
  }) {
    if (value.isEmpty) return const [];

    final issues = <TagFieldIssue>[];

    // Rule 1: Practical max length (10,000 chars)
    if (value.length > maxFieldLength) {
      issues.add(
        TagFieldIssue(
          severity: TagFieldSeverity.error,
          message:
              'Value exceeds maximum length of $maxFieldLength characters '
              '(currently ${value.length}).',
          field: field,
        ),
      );
    }

    // Rule 2: ID3v1 truncation warning
    if (options.writeId3v1) {
      final limit = field == 'year' ? id3v1YearMaxLength : id3v1MaxLength;
      if (value.length > limit) {
        issues.add(
          TagFieldIssue(
            severity: TagFieldSeverity.warning,
            message: 'Will be truncated to $limit characters in the ID3v1 tag.',
            field: field,
          ),
        );
      }
    }

    // Rule 3: Latin-1 encoding — flag non-Latin-1 characters
    if (options.encoding == TagEncoding.latin1) {
      final nonLatin1 = _findNonLatin1Characters(value);
      if (nonLatin1.isNotEmpty) {
        final preview = nonLatin1.length <= 5
            ? nonLatin1.join(', ')
            : '${nonLatin1.take(5).join(', ')}…';
        issues.add(
          TagFieldIssue(
            severity: TagFieldSeverity.error,
            message:
                'Contains characters not representable in Latin-1: $preview. '
                'Switch to UTF-8 or UTF-16 encoding.',
            field: field,
          ),
        );
      }
    }

    // Rule 4: Numeric field validation
    if (numericFields.contains(field)) {
      if (!_isValidNumericValue(value)) {
        issues.add(
          TagFieldIssue(
            severity: TagFieldSeverity.warning,
            message: 'Expected a numeric value.',
            field: field,
          ),
        );
      }
    }

    return issues;
  }

  /// Finds characters in [value] that cannot be represented in ISO 8859-1.
  static List<String> _findNonLatin1Characters(String value) {
    final result = <String>[];
    for (final rune in value.runes) {
      if (rune > 0xFF) {
        result.add(String.fromCharCode(rune));
      }
    }
    return result;
  }

  /// Checks if [value] is a valid numeric tag value.
  ///
  /// Allows plain integers and track/disc number formats like "3/12".
  /// Only "N" or "N/M" formats are valid (at most one slash).
  static bool _isValidNumericValue(String value) {
    // Allow "3/12" format for track/disc numbers
    final parts = value.split('/');
    if (parts.length > 2) return false;
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (int.tryParse(trimmed) == null) return false;
    }
    return true;
  }
}
