import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/sibling_resolver.dart';

void main() {
  final resolver = SiblingResolver();

  group('filterAndSort', () {
    test('excludes hidden folders and sorts case-insensitively', () {
      final result = resolver.filterAndSort(
        ['.hidden', 'Bravo', 'alpha', '.git', 'Charlie'],
      );
      expect(result, ['alpha', 'Bravo', 'Charlie']);
    });

    test('returns empty list when all are hidden', () {
      final result = resolver.filterAndSort(['.a', '.b', '.c']);
      expect(result, isEmpty);
    });

    test('returns empty list for empty input', () {
      final result = resolver.filterAndSort([]);
      expect(result, isEmpty);
    });
  });

  group('resolve', () {
    test('returns next sibling', () {
      final result = resolver.resolve(
        siblingNames: ['alpha', 'Bravo', 'Charlie'],
        currentName: 'Bravo',
        direction: SiblingDirection.next,
      );
      expect(result, 'Charlie');
    });

    test('returns previous sibling', () {
      final result = resolver.resolve(
        siblingNames: ['alpha', 'Bravo', 'Charlie'],
        currentName: 'Bravo',
        direction: SiblingDirection.previous,
      );
      expect(result, 'alpha');
    });

    test('returns null at end boundary', () {
      final result = resolver.resolve(
        siblingNames: ['alpha', 'Bravo', 'Charlie'],
        currentName: 'Charlie',
        direction: SiblingDirection.next,
      );
      expect(result, isNull);
    });

    test('returns null at start boundary', () {
      final result = resolver.resolve(
        siblingNames: ['alpha', 'Bravo', 'Charlie'],
        currentName: 'alpha',
        direction: SiblingDirection.previous,
      );
      expect(result, isNull);
    });

    test('returns null when current name not found', () {
      final result = resolver.resolve(
        siblingNames: ['alpha', 'Bravo', 'Charlie'],
        currentName: 'Delta',
        direction: SiblingDirection.next,
      );
      expect(result, isNull);
    });

    test('matches current name case-insensitively', () {
      final result = resolver.resolve(
        siblingNames: ['alpha', 'Bravo', 'Charlie'],
        currentName: 'bravo',
        direction: SiblingDirection.next,
      );
      expect(result, 'Charlie');
    });
  });
}
