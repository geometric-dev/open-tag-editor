import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/folder_entry.dart';
import 'package:open_tag_editor/features/folder_panel/data/quick_switcher_filter.dart';

void main() {
  late QuickSwitcherFilter filter;

  setUp(() {
    filter = QuickSwitcherFilter();
  });

  final sampleEntries = [
    const FolderEntry(
      path: r'C:\Music\Rock\Led Zeppelin',
      name: 'Led Zeppelin',
      source: FolderEntrySource.bookmark,
    ),
    const FolderEntry(
      path: r'C:\Music\Jazz\Miles Davis',
      name: 'Miles Davis',
      source: FolderEntrySource.recent,
    ),
    const FolderEntry(
      path: r'C:\Music\Electronic\Aphex Twin',
      name: 'Aphex Twin',
      source: FolderEntrySource.bookmark,
    ),
    const FolderEntry(
      path: r'D:\Albums\Classical\Bach',
      name: 'Bach',
      source: FolderEntrySource.recent,
    ),
  ];

  group('QuickSwitcherFilter', () {
    test('returns all entries when query is empty', () {
      final result = filter.filter(sampleEntries, '');
      expect(result, equals(sampleEntries));
    });

    test('filters by name substring (case-insensitive)', () {
      final result = filter.filter(sampleEntries, 'led');
      expect(result, hasLength(1));
      expect(result.first.name, 'Led Zeppelin');
    });

    test('filters by path substring (case-insensitive)', () {
      final result = filter.filter(sampleEntries, 'jazz');
      expect(result, hasLength(1));
      expect(result.first.name, 'Miles Davis');
    });

    test('matches partial name', () {
      final result = filter.filter(sampleEntries, 'twin');
      expect(result, hasLength(1));
      expect(result.first.name, 'Aphex Twin');
    });

    test('matches path drive letter', () {
      final result = filter.filter(sampleEntries, r'D:\');
      expect(result, hasLength(1));
      expect(result.first.name, 'Bach');
    });

    test('returns empty list when no entries match', () {
      final result = filter.filter(sampleEntries, 'nonexistent');
      expect(result, isEmpty);
    });

    test('returns empty list when filtering empty entries list', () {
      final result = filter.filter([], 'query');
      expect(result, isEmpty);
    });

    test('case-insensitive match works for mixed case query', () {
      final result = filter.filter(sampleEntries, 'MILES');
      expect(result, hasLength(1));
      expect(result.first.name, 'Miles Davis');
    });

    test('matches multiple entries when query is broad', () {
      final result = filter.filter(sampleEntries, 'Music');
      expect(result, hasLength(3)); // All C:\Music entries
    });

    test('matches entry via path when name does not contain query', () {
      final result = filter.filter(sampleEntries, 'Albums');
      expect(result, hasLength(1));
      expect(result.first.name, 'Bach');
    });
  });
}
