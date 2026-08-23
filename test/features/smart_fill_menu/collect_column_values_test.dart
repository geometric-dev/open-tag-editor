import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/smart_fill_menu/data/collect_column_values.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

/// Property-based tests for collectColumnValues.
///
/// Each property is tested with 100+ random inputs to verify the invariant
/// holds across the input space.
void main() {
  final random = Random(42);

  // Character pool: ASCII printable + some whitespace chars
  final charPool = [
    ...List.generate(95, (i) => i + 0x20), // ASCII printable (space–tilde)
    0x09, // tab
    0x0A, // newline
    0x0D, // carriage return
  ];

  /// Generates a random string of [length] with characters from [charPool].
  String randomString(int length) {
    return String.fromCharCodes(
      List.generate(length, (_) => charPool[random.nextInt(charPool.length)]),
    );
  }

  /// Value pool that includes empty, whitespace-only, normal, and case variants.
  List<String> generateValuePool() {
    return [
      '', // empty
      ' ', // single space
      '  \t\n', // whitespace-only
      'Rock',
      'rock',
      'ROCK',
      'Pop',
      'Jazz',
      'Blues',
      ...List.generate(5, (_) => randomString(1 + random.nextInt(20))),
    ];
  }

  /// Creates an AudioFile with a given tag value for the test column.
  AudioFile makeFile(int index, String? tagValue) {
    final tags = <String, String>{};
    if (tagValue != null) {
      tags['testCol'] = tagValue;
    }
    return AudioFile(
      path: 'path_$index',
      filename: 'file_$index',
      extension: '.mp3',
      fileSize: 0,
      tags: tags,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Feature: smart-fill-menu, Property 1: collectColumnValues returns unique
  // non-empty values in first-appearance order
  // ─────────────────────────────────────────────────────────────────────────

  // **Validates: Requirements 2.2, 2.4, 5.2, 5.3, 5.4**

  group(
    'Property 1: collectColumnValues returns unique non-empty values in '
    'first-appearance order',
    () {
      test(
        'all elements are non-empty and non-whitespace-only',
        () {
          for (var i = 0; i < 100; i++) {
            final pool = generateValuePool();
            final fileCount = 1 + random.nextInt(50);
            final files = List.generate(fileCount, (idx) {
              final value = pool[random.nextInt(pool.length)];
              return makeFile(idx, value);
            });

            final result = collectColumnValues(
              files: files,
              columnId: 'testCol',
            );

            for (final value in result) {
              expect(
                value.trim().isNotEmpty,
                isTrue,
                reason: 'Every element must be non-empty and non-whitespace-only, '
                    'but got "$value" (iteration $i)',
              );
            }
          }
        },
      );

      test(
        'no duplicates in the result (case-sensitive)',
        () {
          for (var i = 0; i < 100; i++) {
            final pool = generateValuePool();
            final fileCount = 1 + random.nextInt(50);
            final files = List.generate(fileCount, (idx) {
              final value = pool[random.nextInt(pool.length)];
              return makeFile(idx, value);
            });

            final result = collectColumnValues(
              files: files,
              columnId: 'testCol',
            );

            expect(
              result.toSet().length,
              equals(result.length),
              reason: 'Result must contain no duplicates (case-sensitive), '
                  'but got $result (iteration $i)',
            );
          }
        },
      );

      test(
        'order matches first appearance in the input file list',
        () {
          for (var i = 0; i < 100; i++) {
            final pool = generateValuePool();
            final fileCount = 1 + random.nextInt(50);
            final files = List.generate(fileCount, (idx) {
              final value = pool[random.nextInt(pool.length)];
              return makeFile(idx, value);
            });

            final result = collectColumnValues(
              files: files,
              columnId: 'testCol',
            );

            // For each consecutive pair in result, verify first-appearance order
            for (var j = 0; j < result.length - 1; j++) {
              final firstAppearanceA = files.indexWhere(
                (f) => f.tags['testCol'] == result[j],
              );
              final firstAppearanceB = files.indexWhere(
                (f) => f.tags['testCol'] == result[j + 1],
              );

              expect(
                firstAppearanceA < firstAppearanceB,
                isTrue,
                reason: 'Value "${result[j]}" (first at index $firstAppearanceA) '
                    'must appear before "${result[j + 1]}" (first at index '
                    '$firstAppearanceB) in the result (iteration $i)',
              );
            }
          }
        },
      );

      test(
        'no valid value is missing from the result',
        () {
          for (var i = 0; i < 100; i++) {
            final pool = generateValuePool();
            final fileCount = 1 + random.nextInt(50);
            final files = List.generate(fileCount, (idx) {
              final value = pool[random.nextInt(pool.length)];
              return makeFile(idx, value);
            });

            final result = collectColumnValues(
              files: files,
              columnId: 'testCol',
            );

            // Collect all valid values from input files
            final expectedValues = <String>{};
            for (final file in files) {
              final value = file.tags['testCol'] ?? '';
              if (value.trim().isNotEmpty) {
                expectedValues.add(value);
              }
            }

            final resultSet = result.toSet();
            for (final expected in expectedValues) {
              expect(
                resultSet.contains(expected),
                isTrue,
                reason: 'Value "$expected" is present in input files but missing '
                    'from result (iteration $i)',
              );
            }
          }
        },
      );
    },
  );
}
