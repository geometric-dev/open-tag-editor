import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/models/grid_item.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/helpers/grid_navigation.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

FileGridItem _file(String name, int index) => FileGridItem(
  file: AudioFile(
    path: 'C:\\Music\\$name',
    filename: name,
    extension: '.mp3',
    fileSize: 1000,
  ),
  fileIndex: index,
);

SeparatorGridItem _sep(String path) => SeparatorGridItem(relativePath: path);

void main() {
  group('nextFileRowIndex', () {
    test('returns next index for adjacent file rows', () {
      final items = [_file('a', 0), _file('b', 1), _file('c', 2)];

      expect(nextFileRowIndex(items, 0), equals(1));
    });

    test('skips separator between files', () {
      final items = [_file('a', 0), _sep('Rock'), _file('b', 1)];

      expect(nextFileRowIndex(items, 0), equals(2));
    });

    test('skips multiple separators between files', () {
      final items = [_file('a', 0), _sep('Rock'), _sep('Pop'), _file('b', 1)];

      expect(nextFileRowIndex(items, 0), equals(3));
    });

    test('returns null when at last item', () {
      final items = [_file('a', 0), _file('b', 1)];

      expect(nextFileRowIndex(items, 1), isNull);
    });

    test('returns null when no file after current position', () {
      final items = [_file('a', 0), _sep('Rock'), _sep('Pop')];

      expect(nextFileRowIndex(items, 0), isNull);
    });

    test('returns null for negative index', () {
      final items = [_file('a', 0), _file('b', 1)];

      expect(nextFileRowIndex(items, -1), isNull);
    });

    test('returns null when index >= length - 1', () {
      final items = [_file('a', 0), _file('b', 1)];

      expect(nextFileRowIndex(items, 1), isNull);
      expect(nextFileRowIndex(items, 2), isNull);
    });
  });

  group('previousFileRowIndex', () {
    test('returns previous index for adjacent file rows', () {
      final items = [_file('a', 0), _file('b', 1), _file('c', 2)];

      expect(previousFileRowIndex(items, 2), equals(1));
    });

    test('skips separator between files', () {
      final items = [_file('a', 0), _sep('Rock'), _file('b', 1)];

      expect(previousFileRowIndex(items, 2), equals(0));
    });

    test('skips multiple separators between files', () {
      final items = [_file('a', 0), _sep('Rock'), _sep('Pop'), _file('b', 1)];

      expect(previousFileRowIndex(items, 3), equals(0));
    });

    test('returns null when at first item', () {
      final items = [_file('a', 0), _file('b', 1)];

      expect(previousFileRowIndex(items, 0), isNull);
    });

    test('returns null when no file before current position', () {
      final items = [_sep('Rock'), _sep('Pop'), _file('a', 0)];

      expect(previousFileRowIndex(items, 2), isNull);
    });

    test('returns null when index >= length', () {
      final items = [_file('a', 0), _file('b', 1)];

      expect(previousFileRowIndex(items, 2), isNull);
      expect(previousFileRowIndex(items, 3), isNull);
    });
  });

  group('filePathsFromGridItems', () {
    test('extracts file paths from mixed list', () {
      final items = [
        _sep('Rock'),
        _file('a', 0),
        _file('b', 1),
        _sep('Pop'),
        _file('c', 2),
      ];

      expect(
        filePathsFromGridItems(items),
        equals(['C:\\Music\\a', 'C:\\Music\\b', 'C:\\Music\\c']),
      );
    });

    test('returns empty list for empty input', () {
      expect(filePathsFromGridItems([]), equals(<String>[]));
    });

    test('returns empty list when only separators', () {
      final items = [_sep('Rock'), _sep('Pop')];

      expect(filePathsFromGridItems(items), equals(<String>[]));
    });

    test('returns all paths when only files', () {
      final items = [_file('x', 0), _file('y', 1)];

      expect(
        filePathsFromGridItems(items),
        equals(['C:\\Music\\x', 'C:\\Music\\y']),
      );
    });
  });
}
