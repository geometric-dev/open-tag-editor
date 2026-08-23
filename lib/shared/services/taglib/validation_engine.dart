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

        if (actual != effectiveExpected) {
          mismatches
              .add('$field expected \'$effectiveExpected\' got \'$actual\'');
        }
      }
    }

    if (mismatches.isNotEmpty) {
      throw TagWriteException(
        'Validation failed: ${mismatches.join(', ')}',
        path,
      );
    }
  }
}
