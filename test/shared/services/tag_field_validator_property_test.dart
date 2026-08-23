import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/settings/data/models/id3v2_version.dart';
import 'package:open_tag_editor/features/settings/data/models/tag_encoding.dart';
import 'package:open_tag_editor/features/settings/data/models/tag_write_options.dart';
import 'package:open_tag_editor/shared/services/tag_field_validator.dart';

/// Property-based tests for TagFieldValidator.
///
/// Each property is tested with 100+ random inputs to verify the invariant
/// holds across the input space.
void main() {
  final random = Random(42); // Fixed seed for reproducibility

  /// Generates a random string of [length] with characters from [charPool].
  String randomString(int length, List<int> charPool) {
    return String.fromCharCodes(
      List.generate(length, (_) => charPool[random.nextInt(charPool.length)]),
    );
  }

  /// ASCII + Latin-1 extended character pool (0x20–0xFF).
  final latin1Pool = List.generate(224, (i) => i + 0x20);

  /// Pool including non-Latin-1 characters (CJK, Cyrillic, emoji).
  final unicodePool = [
    ...List.generate(94, (i) => i + 0x21), // ASCII printable
    0x4E16, 0x754C, 0x6771, 0x4EAC, // CJK
    0x0427, 0x0430, 0x0439, // Cyrillic
    0x1F3B5, 0x1F3B6, // Emoji (music notes)
  ];

  /// Text fields (not numeric).
  const textFields = ['title', 'artist', 'album', 'comment', 'genre'];

  /// Numeric fields.
  const numericFields = [
    'year',
    'trackNumber',
    'trackTotal',
    'discNumber',
    'discTotal',
    'bpm',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Property 1: ID3v1 truncation warning
  // Feature: tag-field-validation, Property 1: ID3v1 truncation warning
  // ─────────────────────────────────────────────────────────────────────────

  group('Property 1: ID3v1 truncation warning', () {
    const options = TagWriteOptions(
      id3v2Version: Id3v2Version.v24,
      writeId3v1: true,
      encoding: TagEncoding.utf8,
    );

    test('values exceeding limit always produce truncation warning', () {
      for (var i = 0; i < 100; i++) {
        final field = textFields[random.nextInt(textFields.length)];
        final length = 31 + random.nextInt(200); // 31–230 chars
        final value = randomString(length, latin1Pool);

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasTruncationWarning = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.warning &&
              issue.message.contains('truncated'),
        );

        expect(
          hasTruncationWarning,
          isTrue,
          reason: 'Field "$field" with length $length should warn about '
              'truncation (iteration $i)',
        );
      }
    });

    test('values within limit never produce truncation warning', () {
      for (var i = 0; i < 100; i++) {
        final field = textFields[random.nextInt(textFields.length)];
        final length = 1 + random.nextInt(30); // 1–30 chars
        final value = randomString(length, latin1Pool);

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasTruncationWarning = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.warning &&
              issue.message.contains('truncated'),
        );

        expect(
          hasTruncationWarning,
          isFalse,
          reason: 'Field "$field" with length $length should NOT warn about '
              'truncation (iteration $i)',
        );
      }
    });

    test('year field uses 4-char limit', () {
      for (var i = 0; i < 100; i++) {
        final length = 5 + random.nextInt(20); // 5–24 chars
        final value = randomString(length, latin1Pool);

        final issues = TagFieldValidator.validate(
          field: 'year',
          value: value,
          options: options,
        );

        final hasTruncationWarning = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.warning &&
              issue.message.contains('truncated') &&
              issue.message.contains('4'),
        );

        expect(
          hasTruncationWarning,
          isTrue,
          reason: 'Year with length $length should warn about 4-char '
              'truncation (iteration $i)',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 2: Latin-1 encoding error
  // Feature: tag-field-validation, Property 2: Latin-1 encoding error
  // ─────────────────────────────────────────────────────────────────────────

  group('Property 2: Latin-1 encoding error', () {
    const options = TagWriteOptions(
      id3v2Version: Id3v2Version.v24,
      writeId3v1: false,
      encoding: TagEncoding.latin1,
    );

    test('values with non-Latin-1 chars always produce encoding error', () {
      for (var i = 0; i < 100; i++) {
        final field = textFields[random.nextInt(textFields.length)];
        // Generate a string that includes at least one non-Latin-1 char
        final length = 1 + random.nextInt(50);
        final value = randomString(length, unicodePool);

        // Ensure at least one char > 0xFF
        final hasNonLatin1 = value.runes.any((r) => r > 0xFF);
        if (!hasNonLatin1) continue; // Skip if randomly all Latin-1

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasEncodingError = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.error &&
              issue.message.contains('Latin-1'),
        );

        expect(
          hasEncodingError,
          isTrue,
          reason: 'Field "$field" with non-Latin-1 chars should produce '
              'encoding error (iteration $i)',
        );
      }
    });

    test('values with only Latin-1 chars never produce encoding error', () {
      for (var i = 0; i < 100; i++) {
        final field = textFields[random.nextInt(textFields.length)];
        final length = 1 + random.nextInt(50);
        final value = randomString(length, latin1Pool);

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasEncodingError = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.error &&
              issue.message.contains('Latin-1'),
        );

        expect(
          hasEncodingError,
          isFalse,
          reason: 'Field "$field" with only Latin-1 chars should NOT produce '
              'encoding error (iteration $i)',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 3: Maximum length enforcement
  // Feature: tag-field-validation, Property 3: Maximum length enforcement
  // ─────────────────────────────────────────────────────────────────────────

  group('Property 3: Maximum length enforcement', () {
    const options = TagWriteOptions(
      id3v2Version: Id3v2Version.v24,
      writeId3v1: false,
      encoding: TagEncoding.utf8,
    );

    test('values exceeding 10,000 chars always produce max-length error', () {
      for (var i = 0; i < 20; i++) {
        // Fewer iterations due to large string allocation
        final field = textFields[random.nextInt(textFields.length)];
        final length = 10001 + random.nextInt(5000);
        final value = 'A' * length;

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasMaxLengthError = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.error &&
              issue.message.contains('maximum length'),
        );

        expect(
          hasMaxLengthError,
          isTrue,
          reason: 'Field "$field" with length $length should produce '
              'max-length error (iteration $i)',
        );
      }
    });

    test('values within 10,000 chars never produce max-length error', () {
      for (var i = 0; i < 100; i++) {
        final field = textFields[random.nextInt(textFields.length)];
        final length = 1 + random.nextInt(10000);
        final value = randomString(length, latin1Pool);

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasMaxLengthError = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.error &&
              issue.message.contains('maximum length'),
        );

        expect(
          hasMaxLengthError,
          isFalse,
          reason: 'Field "$field" with length $length should NOT produce '
              'max-length error (iteration $i)',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 4: Numeric field validation
  // Feature: tag-field-validation, Property 4: Numeric field validation
  // ─────────────────────────────────────────────────────────────────────────

  group('Property 4: Numeric field validation', () {
    const options = TagWriteOptions(
      id3v2Version: Id3v2Version.v24,
      writeId3v1: false,
      encoding: TagEncoding.utf8,
    );

    test('non-numeric values in numeric fields always produce warning', () {
      final nonNumericValues = [
        'abc',
        'one',
        '12x',
        'fast',
        '3.14',
        'N/A',
        '--',
        '1/2/3',
        'hello world',
        '!@#',
      ];

      for (var i = 0; i < 100; i++) {
        final field = numericFields[random.nextInt(numericFields.length)];
        final value = nonNumericValues[random.nextInt(nonNumericValues.length)];

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasNumericWarning = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.warning &&
              issue.message.contains('numeric'),
        );

        expect(
          hasNumericWarning,
          isTrue,
          reason: 'Numeric field "$field" with value "$value" should produce '
              'numeric warning (iteration $i)',
        );
      }
    });

    test('valid numeric values in numeric fields never produce warning', () {
      for (var i = 0; i < 100; i++) {
        final field = numericFields[random.nextInt(numericFields.length)];
        // Generate valid numeric values: plain integers or "N/M" format
        final n = random.nextInt(999) + 1;
        final useSlash = random.nextBool();
        final value =
            useSlash ? '$n/${random.nextInt(99) + 1}' : n.toString();

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasNumericWarning = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.warning &&
              issue.message.contains('numeric'),
        );

        expect(
          hasNumericWarning,
          isFalse,
          reason: 'Numeric field "$field" with value "$value" should NOT '
              'produce numeric warning (iteration $i)',
        );
      }
    });

    test('non-numeric fields never produce numeric warning', () {
      for (var i = 0; i < 100; i++) {
        final field = textFields[random.nextInt(textFields.length)];
        const value = 'not a number at all';

        final issues = TagFieldValidator.validate(
          field: field,
          value: value,
          options: options,
        );

        final hasNumericWarning = issues.any(
          (issue) =>
              issue.severity == TagFieldSeverity.warning &&
              issue.message.contains('numeric'),
        );

        expect(
          hasNumericWarning,
          isFalse,
          reason: 'Text field "$field" should never produce numeric warning '
              '(iteration $i)',
        );
      }
    });
  });
}
