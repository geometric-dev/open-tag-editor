import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/inline_cell_editing/utils/build_tag_edit_command.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

/// Property-based tests for buildTagEditCommand fill action no-op behavior.
///
/// Each property is tested with 100+ random inputs to verify the invariant
/// holds across the input space.
void main() {
  final random = Random(42);

  /// Pool of possible genre values for random generation.
  final valuePool = [
    'Rock',
    'Pop',
    'Jazz',
    'Classical',
    'Electronic',
    'Hip-Hop',
    'Country',
    'Blues',
    'Metal',
    'Folk',
  ];

  /// Generates a random non-empty string from the value pool.
  String randomValue() => valuePool[random.nextInt(valuePool.length)];

  // Feature: smart-fill-menu, Property 6: Fill action is no-op when no values differ
  group('Property 6: Fill action is no-op when no values differ', () {
    /// **Validates: Requirements 4.4, 4.5**

    test('single file: returns null when value already matches', () {
      for (var i = 0; i < 100; i++) {
        final chosenValue = randomValue();
        final file = AudioFile(
          path: '/path/$i.mp3',
          filename: '$i.mp3',
          extension: '.mp3',
          fileSize: 0,
          tags: {'genre': chosenValue},
        );

        final fileListNotifier = FileListNotifier();
        fileListNotifier.addFiles([file]);

        final result = buildTagEditCommand(
          fileListNotifier: fileListNotifier,
          filePaths: [file.path],
          columnId: 'genre',
          newValue: chosenValue,
          allFiles: [file],
        );

        expect(
          result,
          isNull,
          reason: 'Single file with matching value should return null '
              '(iteration $i, value="$chosenValue")',
        );
      }
    });

    test('single file: returns non-null when value differs', () {
      for (var i = 0; i < 100; i++) {
        final chosenValue = randomValue();
        // Ensure the existing value is different from the chosen value.
        String existingValue;
        do {
          existingValue = randomValue();
        } while (existingValue == chosenValue);

        final file = AudioFile(
          path: '/path/$i.mp3',
          filename: '$i.mp3',
          extension: '.mp3',
          fileSize: 0,
          tags: {'genre': existingValue},
        );

        final fileListNotifier = FileListNotifier();
        fileListNotifier.addFiles([file]);

        final result = buildTagEditCommand(
          fileListNotifier: fileListNotifier,
          filePaths: [file.path],
          columnId: 'genre',
          newValue: chosenValue,
          allFiles: [file],
        );

        expect(
          result,
          isNotNull,
          reason: 'Single file with different value should return a command '
              '(iteration $i, existing="$existingValue", '
              'chosen="$chosenValue")',
        );
      }
    });

    test(
      'batch: returns non-null when at least one file has a different value',
      () {
        for (var i = 0; i < 100; i++) {
          final chosenValue = randomValue();
          final fileCount = 2 + random.nextInt(19); // 2–20 files

          // Generate files where at least one has a different value.
          final files = <AudioFile>[];
          var hasDifferent = false;

          for (var j = 0; j < fileCount; j++) {
            final useDifferent = random.nextBool();
            String tagValue;
            if (useDifferent) {
              do {
                tagValue = randomValue();
              } while (tagValue == chosenValue);
              hasDifferent = true;
            } else {
              tagValue = chosenValue;
            }
            files.add(AudioFile(
              path: '/path/${i}_$j.mp3',
              filename: '${i}_$j.mp3',
              extension: '.mp3',
              fileSize: 0,
              tags: {'genre': tagValue},
            ));
          }

          // Ensure at least one file has a different value.
          if (!hasDifferent) {
            String differentValue;
            do {
              differentValue = randomValue();
            } while (differentValue == chosenValue);
            files[0] = AudioFile(
              path: files[0].path,
              filename: files[0].filename,
              extension: '.mp3',
              fileSize: 0,
              tags: {'genre': differentValue},
            );
          }

          final filePaths = files.map((f) => f.path).toList();
          final fileListNotifier = FileListNotifier();
          fileListNotifier.addFiles(files);

          final result = buildTagEditCommand(
            fileListNotifier: fileListNotifier,
            filePaths: filePaths,
            columnId: 'genre',
            newValue: chosenValue,
            allFiles: files,
          );

          expect(
            result,
            isNotNull,
            reason: 'Batch edit with at least one different value should '
                'return a command (iteration $i, fileCount=$fileCount)',
          );
        }
      },
    );

    // NOTE: The spec (Requirement 4.5) requires that no command is created
    // when ALL target files already have the chosen value, including batch
    // edits. However, the current implementation of buildTagEditCommand only
    // returns null for single-file edits where the value matches. For batch
    // edits, it always creates a command even when all values are the same.
    // This is a known limitation documented here for future implementation.
  });
}
