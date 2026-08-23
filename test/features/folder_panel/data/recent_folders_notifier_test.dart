import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/recent_folders_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Feature: folder-selection-ux, Property 10: Recent folders bounded MRU list
  // Feature: folder-selection-ux, Property 11: Recent folders remove
  // **Validates: Requirements 7.2, 7.4**

  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 10: Recent folders bounded MRU list', () {
    test(
      'list never exceeds 20 entries after any sequence of addFolder operations',
      () {
        final rng = Random(42);

        for (var iteration = 0; iteration < 100; iteration++) {
          SharedPreferences.setMockInitialValues({});
          final notifier = RecentFoldersNotifier();

          // Generate a random sequence of 1–50 addFolder operations.
          final opCount = rng.nextInt(50) + 1;
          for (var op = 0; op < opCount; op++) {
            final path = 'C:\\Folder_${rng.nextInt(30)}';
            notifier.addFolder(path);

            expect(
              notifier.state.length,
              lessThanOrEqualTo(20),
              reason: 'List exceeded 20 entries after adding "$path" '
                  '(iteration $iteration, op $op). '
                  'Length: ${notifier.state.length}',
            );
          }

          notifier.dispose();
        }
      },
    );

    test(
      'most recently added folder is always first in the list',
      () {
        final rng = Random(42);

        for (var iteration = 0; iteration < 100; iteration++) {
          SharedPreferences.setMockInitialValues({});
          final notifier = RecentFoldersNotifier();

          // Generate a random sequence of 1–40 addFolder operations.
          final opCount = rng.nextInt(40) + 1;
          for (var op = 0; op < opCount; op++) {
            final path = 'C:\\Folder_${rng.nextInt(30)}';
            notifier.addFolder(path);

            expect(
              notifier.state.first,
              equals(path),
              reason: 'Most recently added folder "$path" is not first. '
                  'State: ${notifier.state.take(5).toList()} '
                  '(iteration $iteration, op $op)',
            );
          }

          notifier.dispose();
        }
      },
    );

    test(
      'duplicate additions move existing entry to front without creating duplicates',
      () {
        final rng = Random(42);

        for (var iteration = 0; iteration < 100; iteration++) {
          SharedPreferences.setMockInitialValues({});
          final notifier = RecentFoldersNotifier();

          // Seed with some initial folders.
          final seedCount = rng.nextInt(15) + 1;
          for (var i = 0; i < seedCount; i++) {
            notifier.addFolder('C:\\Folder_${rng.nextInt(25)}');
          }

          // Now add a folder that may or may not already be in the list.
          final path = 'C:\\Folder_${rng.nextInt(25)}';
          notifier.addFolder(path);

          // Check no duplicates exist.
          final uniquePaths = notifier.state.toSet();
          expect(
            uniquePaths.length,
            equals(notifier.state.length),
            reason: 'Duplicate entries found after adding "$path". '
                'State: ${notifier.state} (iteration $iteration)',
          );

          // Check the added path is first.
          expect(
            notifier.state.first,
            equals(path),
            reason: 'Added path "$path" is not first after duplicate add. '
                'State: ${notifier.state.take(5).toList()} '
                '(iteration $iteration)',
          );

          notifier.dispose();
        }
      },
    );
  });

  group('Property 11: Recent folders remove', () {
    test(
      'removing a path present in the list results in a list without it and one fewer element',
      () {
        final rng = Random(42);

        for (var iteration = 0; iteration < 100; iteration++) {
          SharedPreferences.setMockInitialValues({});
          final notifier = RecentFoldersNotifier();

          // Seed with unique folders to ensure we have items to remove.
          final seedCount = rng.nextInt(20) + 1;
          final paths = <String>[];
          for (var i = 0; i < seedCount; i++) {
            final path = 'C:\\Folder_$i';
            paths.add(path);
            notifier.addFolder(path);
          }

          // Pick a random path that is in the list.
          final pathToRemove = paths[rng.nextInt(paths.length)];
          final lengthBefore = notifier.state.length;

          // Verify the path is actually in the list before removal.
          expect(
            notifier.state.contains(pathToRemove),
            isTrue,
            reason: 'Path "$pathToRemove" should be in list before removal '
                '(iteration $iteration)',
          );

          notifier.removeFolder(pathToRemove);

          expect(
            notifier.state.contains(pathToRemove),
            isFalse,
            reason: 'Path "$pathToRemove" should not be in list after removal '
                '(iteration $iteration). State: ${notifier.state}',
          );

          expect(
            notifier.state.length,
            equals(lengthBefore - 1),
            reason: 'List should have one fewer element after removal. '
                'Before: $lengthBefore, After: ${notifier.state.length} '
                '(iteration $iteration)',
          );

          notifier.dispose();
        }
      },
    );
  });
}
