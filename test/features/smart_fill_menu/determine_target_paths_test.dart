import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/smart_fill_menu/data/determine_target_paths.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

/// Property-based tests for determineTargetPaths.
///
/// Each property is tested with 100+ random inputs to verify the invariant
/// holds across the input space.
void main() {
  final random = Random(42);

  // Feature: smart-fill-menu, Property 5: determineTargetPaths scope correctness
  group('Property 5: determineTargetPaths scope correctness', () {
    /// **Validates: Requirements 4.1, 4.2, 7.2**

    /// Generates a list of AudioFile objects with unique paths.
    List<AudioFile> generateFiles(int count) {
      return List.generate(
        count,
        (i) => AudioFile(
          path: '/path/$i.mp3',
          filename: '$i.mp3',
          extension: '.mp3',
          fileSize: 0,
        ),
      );
    }

    test('returns all paths when selection is empty', () {
      for (var i = 0; i < 100; i++) {
        final fileCount = 1 + random.nextInt(50);
        final files = generateFiles(fileCount);
        final selectedPaths = <String>{};

        final result = determineTargetPaths(
          selectedPaths: selectedPaths,
          allFiles: files,
        );

        expect(
          result.length,
          equals(files.length),
          reason:
              'When selection is empty, result should contain all '
              'file paths (iteration $i, fileCount=$fileCount)',
        );
        expect(
          result.toSet(),
          equals(files.map((f) => f.path).toSet()),
          reason:
              'When selection is empty, result should match all '
              'file paths as a set (iteration $i)',
        );
      }
    });

    test('returns all paths when selection is full', () {
      for (var i = 0; i < 100; i++) {
        final fileCount = 1 + random.nextInt(50);
        final files = generateFiles(fileCount);
        final selectedPaths = files.map((f) => f.path).toSet();

        final result = determineTargetPaths(
          selectedPaths: selectedPaths,
          allFiles: files,
        );

        expect(
          result.length,
          equals(files.length),
          reason:
              'When all files are selected, result should contain all '
              'file paths (iteration $i, fileCount=$fileCount)',
        );
        expect(
          result.toSet(),
          equals(files.map((f) => f.path).toSet()),
          reason:
              'When all files are selected, result should match all '
              'file paths as a set (iteration $i)',
        );
      }
    });

    test('returns only selected paths when selection is a proper subset', () {
      for (var i = 0; i < 100; i++) {
        final fileCount = 2 + random.nextInt(49);
        final files = generateFiles(fileCount);
        final allPaths = files.map((f) => f.path).toList();

        // Generate a proper subset: non-empty and not all.
        // Use random probability to include each path.
        final selectedPaths = <String>{};
        for (final path in allPaths) {
          if (random.nextDouble() < 0.5) {
            selectedPaths.add(path);
          }
        }

        // Ensure it's a proper subset (non-empty and not all).
        if (selectedPaths.isEmpty) {
          selectedPaths.add(allPaths.first);
        }
        if (selectedPaths.length == allPaths.length) {
          selectedPaths.remove(allPaths.last);
        }

        final result = determineTargetPaths(
          selectedPaths: selectedPaths,
          allFiles: files,
        );

        expect(
          result.toSet(),
          equals(selectedPaths),
          reason:
              'When selection is a proper subset, result should contain '
              'exactly the selected paths (iteration $i, '
              'selected=${selectedPaths.length}/${files.length})',
        );
      }
    });
  });
}
