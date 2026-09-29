import '../../../features/tools/data/multi_value.dart';
import '../tag_reader_service.dart';

/// Re-reads files after writes to confirm tags were persisted correctly.
///
/// Uses a [TagReaderService] to read back written tags and compares them
/// against the expected values, throwing [TagWriteException] on mismatch.
class ValidationEngine {
  /// Creates a [ValidationEngine] with the given [reader].
  ValidationEngine(this._reader);

  final TagReaderService _reader;

  /// Validates that [expectedTags] were persisted to [path].
  ///
  /// Re-reads the file and compares written fields against intended values.
  /// Throws [TagWriteException] with mismatch details on failure.
  Future<void> validate(String path, Map<String, String> expectedTags) async {
    final audioFile = await _reader.readTags(path);
    final actualTags = audioFile.tags;
    final mismatches = <String>[];

    for (final entry in expectedTags.entries) {
      final field = entry.key;
      final expected = entry.value;
      final actual = actualTags[field] ?? '';

      if (expected.isEmpty) {
        // Expect the field to be absent or empty.
        if (actual.isNotEmpty) {
          mismatches.add('$field expected empty got \'$actual\'');
        }
      } else {
        // For track/disc number fields, the reader splits "3/16" into
        // trackNumber="3" + trackTotal="16". Compare against just the
        // number portion when the expected value contains a slash.
        final effectiveExpected =
            (field == 'trackNumber' || field == 'discNumber') &&
                expected.contains('/')
            ? expected.split('/').first
            : expected;

        if (actual == effectiveExpected) continue;

        // Multi-value fields are compared as ordered value lists rather than
        // as raw strings. The writer normalises (drops empty segments,
        // applies the configured separator) and the reader rejoins for
        // display, so comparing the joined text verbatim would fail the
        // write for any input that was not already perfectly normalised —
        // and aborting the write is the opposite of what validation is for.
        if (isMultiValueField(field) &&
            _sameValues(
              _values(effectiveExpected, field),
              _values(actual, field),
            )) {
          continue;
        }

        mismatches.add(
          '$field expected \'$effectiveExpected\' got \'$actual\'',
        );
      }
    }

    if (mismatches.isNotEmpty) {
      throw TagWriteException(
        'Validation failed: ${mismatches.join(', ')}',
        path,
      );
    }
  }

  /// Splits [raw] into its individual values, for multi-value comparison.
  List<String> _values(String raw, String field) =>
      MultiValue.parse(raw, field, splitSingleValueFields: true);

  /// Whether two value lists are equal, ignoring order.
  ///
  /// Order is deliberately ignored: Vorbis Comments and ID3v2 do not
  /// guarantee it is preserved on every round trip, and a reorder is not a
  /// failed write. Values themselves are compared case-sensitively, because
  /// "Rock" and "rock" in the same field is a real difference the user
  /// should see.
  bool _sameValues(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final remaining = [...b];
    for (final value in a) {
      final index = remaining.indexOf(value);
      if (index < 0) return false;
      remaining.removeAt(index);
    }
    return true;
  }
}
