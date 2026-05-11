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
        // Expect an exact match.
        if (actual != expected) {
          mismatches.add('$field expected \'$expected\' got \'$actual\'');
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
