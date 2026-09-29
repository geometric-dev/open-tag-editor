import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/bookmark_entry.dart';
import 'package:open_tag_editor/features/folder_panel/data/bookmarks_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Property-based tests for [BookmarksNotifier].
///
/// Validates Properties 2, 3, 4, 5, 6:
/// - Property 2: Bookmark add is append-only and idempotent
/// - Property 3: Bookmark remove
/// - Property 4: Bookmark persistence round-trip preserving order
/// - Property 5: Bookmark reorder preserves elements
/// - Property 6: Bookmark maximum capacity
///
/// **Validates: Requirements 2.2, 2.3, 2.5, 2.6, 2.7, 2.8, 2.10**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Generates a unique folder path for the given index.
  String generatePath(int i) => 'C:\\Folder_$i';

  /// Generates a random list of unique bookmark paths of the given length.
  List<String> generateUniquePaths(Random rng, int count) {
    final paths = <String>[];
    for (var i = 0; i < count; i++) {
      paths.add(generatePath(i));
    }
    return paths;
  }

  /// Creates a BookmarksNotifier pre-populated with the given paths.
  BookmarksNotifier createNotifierWithPaths(List<String> paths) {
    SharedPreferences.setMockInitialValues({});
    final notifier = BookmarksNotifier();
    for (final path in paths) {
      notifier.addBookmark(path);
    }
    return notifier;
  }

  group('Property 2: Bookmark add is append-only and idempotent', () {
    // Feature: folder-selection-ux, Property 2: Bookmark add is append-only and idempotent
    // **Validates: Requirements 2.2, 2.3**

    test('adding a new path appends to end when list < 50', () {
      final rng = Random(42);

      for (var i = 0; i < 100; i++) {
        SharedPreferences.setMockInitialValues({});
        final initialCount = rng.nextInt(49); // 0 to 48
        final paths = generateUniquePaths(rng, initialCount);
        final notifier = createNotifierWithPaths(paths);

        final newPath = 'C:\\NewFolder_${rng.nextInt(10000) + 1000}';

        // Ensure newPath is not already in the list
        final isNew = !paths.contains(newPath);
        if (!isNew) {
          notifier.dispose();
          continue;
        }

        final stateBefore = List<BookmarkEntry>.from(notifier.state);
        notifier.addBookmark(newPath);
        final stateAfter = notifier.state;

        // Should have one more element
        expect(
          stateAfter.length,
          equals(stateBefore.length + 1),
          reason:
              'Adding new path should increase list size by 1 '
              '(iteration $i)',
        );

        // Last element should be the new path
        expect(
          stateAfter.last.path,
          equals(newPath),
          reason: 'New path should be appended to end (iteration $i)',
        );

        // All previous elements should be unchanged
        for (var j = 0; j < stateBefore.length; j++) {
          expect(
            stateAfter[j].path,
            equals(stateBefore[j].path),
            reason: 'Existing elements should be unchanged (iteration $i)',
          );
        }

        notifier.dispose();
      }
    });

    test('adding a duplicate path leaves list unchanged (idempotent)', () {
      final rng = Random(43);

      for (var i = 0; i < 100; i++) {
        SharedPreferences.setMockInitialValues({});
        final count = rng.nextInt(49) + 1; // 1 to 49
        final paths = generateUniquePaths(rng, count);
        final notifier = createNotifierWithPaths(paths);

        // Pick a random existing path to add again
        final duplicatePath = paths[rng.nextInt(paths.length)];
        final stateBefore = List<BookmarkEntry>.from(notifier.state);

        notifier.addBookmark(duplicatePath);
        final stateAfter = notifier.state;

        // List should be unchanged
        expect(
          stateAfter.length,
          equals(stateBefore.length),
          reason:
              'Adding duplicate should not change list size '
              '(iteration $i)',
        );

        for (var j = 0; j < stateBefore.length; j++) {
          expect(
            stateAfter[j].path,
            equals(stateBefore[j].path),
            reason:
                'Adding duplicate should not change any element '
                '(iteration $i, index $j)',
          );
        }

        notifier.dispose();
      }
    });
  });

  group('Property 3: Bookmark remove', () {
    // Feature: folder-selection-ux, Property 3: Bookmark remove
    // **Validates: Requirements 2.5**

    test(
      'removing a present path results in list without it and one fewer element',
      () {
        final rng = Random(44);

        for (var i = 0; i < 100; i++) {
          SharedPreferences.setMockInitialValues({});
          final count = rng.nextInt(49) + 1; // 1 to 49
          final paths = generateUniquePaths(rng, count);
          final notifier = createNotifierWithPaths(paths);

          // Pick a random path to remove
          final pathToRemove = paths[rng.nextInt(paths.length)];
          final sizeBefore = notifier.state.length;

          notifier.removeBookmark(pathToRemove);
          final stateAfter = notifier.state;

          // Should have one fewer element
          expect(
            stateAfter.length,
            equals(sizeBefore - 1),
            reason:
                'Removing present path should decrease size by 1 '
                '(iteration $i)',
          );

          // Should not contain the removed path
          expect(
            stateAfter.any((e) => e.path == pathToRemove),
            isFalse,
            reason: 'Removed path should not be in list (iteration $i)',
          );

          notifier.dispose();
        }
      },
    );

    test('removing an absent path leaves list unchanged', () {
      final rng = Random(45);

      for (var i = 0; i < 100; i++) {
        SharedPreferences.setMockInitialValues({});
        final count = rng.nextInt(50); // 0 to 49
        final paths = generateUniquePaths(rng, count);
        final notifier = createNotifierWithPaths(paths);

        // Use a path that is definitely not in the list
        final absentPath = 'C:\\NonExistent_${rng.nextInt(10000) + 5000}';
        final stateBefore = List<BookmarkEntry>.from(notifier.state);

        notifier.removeBookmark(absentPath);
        final stateAfter = notifier.state;

        // List should be unchanged
        expect(
          stateAfter.length,
          equals(stateBefore.length),
          reason:
              'Removing absent path should not change size '
              '(iteration $i)',
        );

        for (var j = 0; j < stateBefore.length; j++) {
          expect(
            stateAfter[j].path,
            equals(stateBefore[j].path),
            reason:
                'Removing absent path should not change any element '
                '(iteration $i, index $j)',
          );
        }

        notifier.dispose();
      }
    });
  });

  group('Property 4: Bookmark persistence round-trip preserving order', () {
    // Feature: folder-selection-ux, Property 4: Bookmark persistence round-trip preserving order
    // **Validates: Requirements 2.6, 2.8**

    test(
      'serializing to JSON and deserializing back produces equivalent list in same order',
      () {
        final rng = Random(46);

        for (var i = 0; i < 100; i++) {
          final count = rng.nextInt(50) + 1; // 1 to 50
          final paths = generateUniquePaths(rng, count);

          // Create BookmarkEntry list
          final entries = paths.map(BookmarkEntry.fromPath).toList();

          // Serialize to JSON
          final json = jsonEncode(entries.map((e) => e.toJson()).toList());

          // Deserialize back
          final decoded = (jsonDecode(json) as List)
              .cast<Map<String, dynamic>>()
              .map(BookmarkEntry.fromJson)
              .toList();

          // Should have same length
          expect(
            decoded.length,
            equals(entries.length),
            reason: 'Round-trip should preserve list length (iteration $i)',
          );

          // Should have same entries in same order
          for (var j = 0; j < entries.length; j++) {
            expect(
              decoded[j].path,
              equals(entries[j].path),
              reason:
                  'Round-trip should preserve path at index $j '
                  '(iteration $i)',
            );
            expect(
              decoded[j].name,
              equals(entries[j].name),
              reason:
                  'Round-trip should preserve name at index $j '
                  '(iteration $i)',
            );
          }
        }
      },
    );

    test('notifier persist and reload preserves bookmarks in order', () async {
      final rng = Random(47);

      for (var i = 0; i < 100; i++) {
        SharedPreferences.setMockInitialValues({});
        final count = rng.nextInt(20) + 1; // 1 to 20 (keep fast)
        final paths = generateUniquePaths(rng, count);
        final notifier = createNotifierWithPaths(paths);

        // Allow async persist to complete
        await Future<void>.delayed(Duration.zero);

        // Get the current prefs state
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('bookmarks_v1');

        // Create a fresh notifier and load from prefs
        SharedPreferences.setMockInitialValues(
          savedJson != null ? {'bookmarks_v1': savedJson} : {},
        );
        final reloaded = BookmarksNotifier();
        await reloaded.loadFromPrefs();

        // Should have same entries in same order
        expect(
          reloaded.state.length,
          equals(notifier.state.length),
          reason: 'Reloaded notifier should have same count (iteration $i)',
        );

        for (var j = 0; j < notifier.state.length; j++) {
          expect(
            reloaded.state[j].path,
            equals(notifier.state[j].path),
            reason: 'Reloaded path should match at index $j (iteration $i)',
          );
          expect(
            reloaded.state[j].name,
            equals(notifier.state[j].name),
            reason: 'Reloaded name should match at index $j (iteration $i)',
          );
        }

        notifier.dispose();
        reloaded.dispose();
      }
    });
  });

  group('Property 5: Bookmark reorder preserves elements', () {
    // Feature: folder-selection-ux, Property 5: Bookmark reorder preserves elements
    // **Validates: Requirements 2.7**

    test(
      'reorder(i, j) results in same set of elements with only order changed',
      () {
        final rng = Random(48);

        for (var i = 0; i < 100; i++) {
          SharedPreferences.setMockInitialValues({});
          final count = rng.nextInt(48) + 2; // 2 to 49 (need at least 2)
          final paths = generateUniquePaths(rng, count);
          final notifier = createNotifierWithPaths(paths);

          final stateBefore = List<BookmarkEntry>.from(notifier.state);

          // Generate valid reorder indices using Flutter's convention:
          // oldIndex: 0..length-1
          // newIndex: 0..length (Flutter ReorderableListView convention)
          final oldIndex = rng.nextInt(stateBefore.length);
          final newIndex = rng.nextInt(stateBefore.length + 1);

          notifier.reorder(oldIndex, newIndex);
          final stateAfter = notifier.state;

          // Same number of elements
          expect(
            stateAfter.length,
            equals(stateBefore.length),
            reason:
                'Reorder should preserve list size '
                '(iteration $i, old=$oldIndex, new=$newIndex)',
          );

          // Same set of paths (sorted for comparison)
          final pathsBefore = stateBefore.map((e) => e.path).toList()..sort();
          final pathsAfter = stateAfter.map((e) => e.path).toList()..sort();

          expect(
            pathsAfter,
            equals(pathsBefore),
            reason:
                'Reorder should preserve the same set of elements '
                '(iteration $i, old=$oldIndex, new=$newIndex)',
          );

          notifier.dispose();
        }
      },
    );
  });

  group('Property 6: Bookmark maximum capacity', () {
    // Feature: folder-selection-ux, Property 6: Bookmark maximum capacity
    // **Validates: Requirements 2.10**

    test(
      'list at 50 entries, adding new bookmark does not increase size beyond 50',
      () {
        final rng = Random(49);

        for (var i = 0; i < 100; i++) {
          SharedPreferences.setMockInitialValues({});
          // Fill to exactly 50
          final paths = generateUniquePaths(rng, 50);
          final notifier = createNotifierWithPaths(paths);

          expect(
            notifier.state.length,
            equals(50),
            reason: 'Precondition: list should be at capacity (iteration $i)',
          );

          // Try to add a new unique path
          final newPath = 'C:\\Overflow_${rng.nextInt(10000) + 9000}';
          notifier.addBookmark(newPath);

          // Size should not exceed 50
          expect(
            notifier.state.length,
            lessThanOrEqualTo(50),
            reason:
                'Adding to full list should not exceed max capacity '
                '(iteration $i)',
          );

          // The new path should NOT be in the list
          expect(
            notifier.state.any((e) => e.path == newPath),
            isFalse,
            reason:
                'New path should not be added when at capacity '
                '(iteration $i)',
          );

          notifier.dispose();
        }
      },
    );
  });
}
