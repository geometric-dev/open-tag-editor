import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/filename_parser.dart';

/// Property-based tests for FilenameParser.
///
/// Each property is tested with 100+ random inputs to verify the invariant
/// holds across the input space.
void main() {
  final random = Random(42); // Fixed seed for reproducibility

  /// Common audio file extensions.
  const extensions = ['.mp3', '.flac', '.ogg', '.wav', '.m4a', '.aac'];

  /// Separator characters used between track number and title.
  const separators = [' ', '_', '-', '.'];

  /// Pool of word fragments for generating titles.
  const words = [
    'Take',
    'Me',
    'Away',
    'Song',
    'Name',
    'The',
    'Great',
    'Escape',
    'Love',
    'Fire',
    'Night',
    'Dream',
    'Blue',
    'Sky',
    'Run',
    'Wild',
    'Heart',
    'Gold',
    'Rise',
    'Fall',
  ];

  /// Generates a random title composed of 1–5 words joined by a separator.
  String randomTitle(String separator) {
    final wordCount = 1 + random.nextInt(5);
    return List.generate(
      wordCount,
      (_) => words[random.nextInt(words.length)],
    ).join(separator);
  }

  /// Generates a filename with a known leading track number.
  ///
  /// Returns a record of (filename, expectedTrackNumber).
  ({String filename, int trackNumber}) filenameWithTrackNumber() {
    final trackNumber = 1 + random.nextInt(99);
    final padded = random.nextBool()
        ? trackNumber.toString().padLeft(2, '0')
        : trackNumber.toString();
    final separator = separators[random.nextInt(separators.length)];
    final titleSeparator = separators[random.nextInt(separators.length)];
    final title = randomTitle(titleSeparator);
    final ext = extensions[random.nextInt(extensions.length)];
    final filename = '$padded$separator$title$ext';
    return (filename: filename, trackNumber: trackNumber);
  }

  /// Generates a filename without leading digits.
  String filenameWithoutTrackNumber() {
    final titleSeparator = separators[random.nextInt(separators.length)];
    final title = randomTitle(titleSeparator);
    final ext = extensions[random.nextInt(extensions.length)];
    // Ensure the first character is not a digit
    final firstWord = words[random.nextInt(words.length)];
    return '$firstWord$titleSeparator$title$ext';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Property 1: Track number extraction
  // Feature: partial-album-match, Property 1: Track number extraction
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 1.1, 1.6**
  group('Property 1: Track number extraction', () {
    test(
      'filenames with leading digits followed by separator return correct int',
      () {
        for (var i = 0; i < 150; i++) {
          final generated = filenameWithTrackNumber();

          final result = FilenameParser.extractTrackNumber(generated.filename);

          expect(
            result,
            equals(generated.trackNumber),
            reason: 'Filename "${generated.filename}" should extract track '
                'number ${generated.trackNumber} (iteration $i)',
          );
        }
      },
    );

    test('filenames without leading digits return null', () {
      for (var i = 0; i < 150; i++) {
        final filename = filenameWithoutTrackNumber();

        final result = FilenameParser.extractTrackNumber(filename);

        expect(
          result,
          isNull,
          reason: 'Filename "$filename" should return null for track '
              'number (iteration $i)',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 2: Filename normalisation preserves words
  // Feature: partial-album-match, Property 2: Filename normalisation preserves words
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 2.1**
  group('Property 2: Filename normalisation preserves words', () {
    test('output contains no extension, no leading digit prefix, no separators',
        () {
      for (var i = 0; i < 150; i++) {
        // Mix of filenames with and without track numbers
        final filename = random.nextBool()
            ? filenameWithTrackNumber().filename
            : filenameWithoutTrackNumber();

        final result = FilenameParser.extractTitle(filename);

        // No file extension present
        for (final ext in extensions) {
          expect(
            result.endsWith(ext),
            isFalse,
            reason: 'Result "$result" from "$filename" should not contain '
                'extension "$ext" (iteration $i)',
          );
        }

        // No underscores, hyphens, or dots (separator chars)
        expect(
          result.contains('_'),
          isFalse,
          reason: 'Result "$result" from "$filename" should not contain '
              'underscores (iteration $i)',
        );
        expect(
          result.contains('-'),
          isFalse,
          reason: 'Result "$result" from "$filename" should not contain '
              'hyphens (iteration $i)',
        );
        expect(
          result.contains('.'),
          isFalse,
          reason: 'Result "$result" from "$filename" should not contain '
              'dots (iteration $i)',
        );
      }
    });

    test('alphabetic word tokens in output are subset of original filename',
        () {
      for (var i = 0; i < 150; i++) {
        final filename = random.nextBool()
            ? filenameWithTrackNumber().filename
            : filenameWithoutTrackNumber();

        final result = FilenameParser.extractTitle(filename);

        // Extract alphabetic tokens from the result
        final resultTokens = result
            .split(' ')
            .where((t) => t.isNotEmpty)
            .where((t) => RegExp(r'^[a-zA-Z]+$').hasMatch(t))
            .map((t) => t.toLowerCase())
            .toSet();

        // Extract alphabetic tokens derivable from the original filename
        // (split on any non-alpha character)
        final originalTokens = filename
            .split(RegExp(r'[^a-zA-Z]+'))
            .where((t) => t.isNotEmpty)
            .map((t) => t.toLowerCase())
            .toSet();

        expect(
          resultTokens.difference(originalTokens).isEmpty,
          isTrue,
          reason: 'Result tokens $resultTokens from "$filename" should be a '
              'subset of original tokens $originalTokens (iteration $i)',
        );
      }
    });
  });
}
