import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/sibling_resolver.dart';

/// Generates a random directory name (visible, not dot-prefixed).
String _randomVisibleName(Random rng) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
  final length = rng.nextInt(10) + 1;
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// Generates a random hidden directory name (dot-prefixed).
String _randomHiddenName(Random rng) {
  return '.${_randomVisibleName(rng)}';
}

/// Generates a random list of directory names including both visible and hidden.
List<String> _randomDirectoryNames(Random rng) {
  final count = rng.nextInt(15) + 1;
  return List.generate(count, (_) {
    if (rng.nextBool()) {
      return _randomHiddenName(rng);
    }
    return _randomVisibleName(rng);
  });
}

void main() {
  // Feature: folder-selection-ux, Property 9: Sibling folder resolution with hidden folder exclusion
  // **Validates: Requirements 6.1, 6.2, 6.8**

  final resolver = SiblingResolver();

  group('Property 9: Sibling folder resolution with hidden folder exclusion', () {
    test('filterAndSort excludes all hidden names (dot-prefixed)', () {
      final rng = Random(42);

      for (var i = 0; i < 100; i++) {
        final names = _randomDirectoryNames(rng);
        final result = resolver.filterAndSort(names);

        for (final name in result) {
          expect(
            name.startsWith('.'),
            isFalse,
            reason:
                'Filtered list should not contain hidden name "$name" '
                '(iteration $i, input: $names)',
          );
        }
      }
    });

    test('filterAndSort result is sorted case-insensitively', () {
      final rng = Random(123);

      for (var i = 0; i < 100; i++) {
        final names = _randomDirectoryNames(rng);
        final result = resolver.filterAndSort(names);

        for (var j = 0; j < result.length - 1; j++) {
          final cmp = result[j].toLowerCase().compareTo(
            result[j + 1].toLowerCase(),
          );
          expect(
            cmp <= 0,
            isTrue,
            reason:
                'Expected "${result[j]}" <= "${result[j + 1]}" '
                '(case-insensitive) at index $j (iteration $i)',
          );
        }
      }
    });

    test('filterAndSort preserves all non-hidden names', () {
      final rng = Random(7);

      for (var i = 0; i < 100; i++) {
        final names = _randomDirectoryNames(rng);
        final result = resolver.filterAndSort(names);
        final expectedVisible = names.where((n) => !n.startsWith('.')).toList();

        // Same elements (as a set, ignoring order)
        expect(
          result.toSet(),
          equals(expectedVisible.toSet()),
          reason:
              'Filtered result should contain exactly the non-hidden names '
              '(iteration $i)',
        );
      }
    });

    test(
      'resolve next returns entry immediately after current in sorted order',
      () {
        final rng = Random(99);

        for (var i = 0; i < 100; i++) {
          final names = _randomDirectoryNames(rng);
          final sorted = resolver.filterAndSort(names);
          if (sorted.isEmpty) continue;

          // Pick a random current name from the sorted list
          final currentIndex = rng.nextInt(sorted.length);
          final currentName = sorted[currentIndex];

          final result = resolver.resolve(
            siblingNames: sorted,
            currentName: currentName,
            direction: SiblingDirection.next,
          );

          if (currentIndex >= sorted.length - 1) {
            expect(
              result,
              isNull,
              reason:
                  'Expected null for last element "$currentName" '
                  '(iteration $i, list: $sorted)',
            );
          } else {
            expect(
              result,
              equals(sorted[currentIndex + 1]),
              reason:
                  'Expected next sibling "${sorted[currentIndex + 1]}" '
                  'after "$currentName" (iteration $i, list: $sorted)',
            );
          }
        }
      },
    );

    test(
      'resolve previous returns entry immediately before current in sorted order',
      () {
        final rng = Random(256);

        for (var i = 0; i < 100; i++) {
          final names = _randomDirectoryNames(rng);
          final sorted = resolver.filterAndSort(names);
          if (sorted.isEmpty) continue;

          // Pick a random current name from the sorted list
          final currentIndex = rng.nextInt(sorted.length);
          final currentName = sorted[currentIndex];

          final result = resolver.resolve(
            siblingNames: sorted,
            currentName: currentName,
            direction: SiblingDirection.previous,
          );

          if (currentIndex <= 0) {
            expect(
              result,
              isNull,
              reason:
                  'Expected null for first element "$currentName" '
                  '(iteration $i, list: $sorted)',
            );
          } else {
            expect(
              result,
              equals(sorted[currentIndex - 1]),
              reason:
                  'Expected previous sibling "${sorted[currentIndex - 1]}" '
                  'before "$currentName" (iteration $i, list: $sorted)',
            );
          }
        }
      },
    );

    test('resolve returns null at last boundary (next direction)', () {
      final rng = Random(500);

      for (var i = 0; i < 100; i++) {
        final names = _randomDirectoryNames(rng);
        final sorted = resolver.filterAndSort(names);
        if (sorted.isEmpty) continue;

        final lastEntry = sorted.last;
        final result = resolver.resolve(
          siblingNames: sorted,
          currentName: lastEntry,
          direction: SiblingDirection.next,
        );

        expect(
          result,
          isNull,
          reason:
              'Expected null when resolving next from last entry '
              '"$lastEntry" (iteration $i)',
        );
      }
    });

    test('resolve returns null at first boundary (previous direction)', () {
      final rng = Random(777);

      for (var i = 0; i < 100; i++) {
        final names = _randomDirectoryNames(rng);
        final sorted = resolver.filterAndSort(names);
        if (sorted.isEmpty) continue;

        final firstEntry = sorted.first;
        final result = resolver.resolve(
          siblingNames: sorted,
          currentName: firstEntry,
          direction: SiblingDirection.previous,
        );

        expect(
          result,
          isNull,
          reason:
              'Expected null when resolving previous from first entry '
              '"$firstEntry" (iteration $i)',
        );
      }
    });
  });
}
