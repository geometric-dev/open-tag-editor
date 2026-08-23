import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/sibling_resolver.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Sibling navigation integration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sibling_nav_test_');
      Directory(p.join(tempDir.path, 'alpha')).createSync();
      Directory(p.join(tempDir.path, 'bravo')).createSync();
      Directory(p.join(tempDir.path, 'charlie')).createSync();
      Directory(p.join(tempDir.path, '.hidden')).createSync();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('lists siblings from real directory, excludes hidden, sorts', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      expect(sorted, ['alpha', 'bravo', 'charlie']);
    });

    test('Alt+Right: resolves next sibling from first', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      final next = resolver.resolve(
        siblingNames: sorted,
        currentName: 'alpha',
        direction: SiblingDirection.next,
      );

      expect(next, 'bravo');
    });

    test('Alt+Left: resolves previous sibling from last', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      final previous = resolver.resolve(
        siblingNames: sorted,
        currentName: 'charlie',
        direction: SiblingDirection.previous,
      );

      expect(previous, 'bravo');
    });

    test('boundary: no next sibling when at last folder', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      final next = resolver.resolve(
        siblingNames: sorted,
        currentName: 'charlie',
        direction: SiblingDirection.next,
      );

      expect(next, isNull);
    });

    test('boundary: no previous sibling when at first folder', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      final previous = resolver.resolve(
        siblingNames: sorted,
        currentName: 'alpha',
        direction: SiblingDirection.previous,
      );

      expect(previous, isNull);
    });

    test('no-op when current folder not found in siblings', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      final result = resolver.resolve(
        siblingNames: sorted,
        currentName: 'nonexistent',
        direction: SiblingDirection.next,
      );

      expect(result, isNull);
    });

    test('hidden folders are excluded from sibling list', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      expect(sorted, isNot(contains('.hidden')));
      expect(sorted.length, 3);
    });

    test('sequential navigation: alpha -> bravo -> charlie', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      // Start at alpha, navigate next twice
      final second = resolver.resolve(
        siblingNames: sorted,
        currentName: 'alpha',
        direction: SiblingDirection.next,
      );
      expect(second, 'bravo');

      final third = resolver.resolve(
        siblingNames: sorted,
        currentName: second!,
        direction: SiblingDirection.next,
      );
      expect(third, 'charlie');

      // Navigate back
      final backToSecond = resolver.resolve(
        siblingNames: sorted,
        currentName: third!,
        direction: SiblingDirection.previous,
      );
      expect(backToSecond, 'bravo');

      final backToFirst = resolver.resolve(
        siblingNames: sorted,
        currentName: backToSecond!,
        direction: SiblingDirection.previous,
      );
      expect(backToFirst, 'alpha');
    });

    test('no-op when no folder loaded (empty sibling list)', () {
      // Simulates the case where loadedFolderPathProvider is null:
      // SiblingNavigationService would return early, but we can test
      // that resolve handles an empty list gracefully.
      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort([]);

      expect(sorted, isEmpty);

      final result = resolver.resolve(
        siblingNames: sorted,
        currentName: 'anything',
        direction: SiblingDirection.next,
      );

      expect(result, isNull);
    });

    test('case-insensitive matching of current folder name', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      // Use uppercase variant of 'bravo'
      final next = resolver.resolve(
        siblingNames: sorted,
        currentName: 'BRAVO',
        direction: SiblingDirection.next,
      );

      expect(next, 'charlie');
    });

    test('target path construction after resolve', () {
      final entries = tempDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();

      final resolver = SiblingResolver();
      final sorted = resolver.filterAndSort(entries);

      final currentPath = p.join(tempDir.path, 'alpha');
      final parentPath = p.dirname(currentPath);
      final targetName = resolver.resolve(
        siblingNames: sorted,
        currentName: p.basename(currentPath),
        direction: SiblingDirection.next,
      );

      expect(targetName, isNotNull);
      final targetPath = p.join(parentPath, targetName!);
      expect(Directory(targetPath).existsSync(), isTrue);
    });
  });
}
