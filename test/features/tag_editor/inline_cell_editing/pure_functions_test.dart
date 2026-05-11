import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/inline_cell_editing/utils/column_editability.dart';
import 'package:open_tag_editor/features/tag_editor/inline_cell_editing/utils/cell_navigation.dart';
import 'package:open_tag_editor/features/tag_editor/inline_cell_editing/models/cell_coordinate.dart';

void main() {
  group('isColumnEditable', () {
    group('read-only columns return false', () {
      test('tagIndicator is not editable', () {
        expect(isColumnEditable('tagIndicator'), isFalse);
      });

      test('filename is not editable', () {
        expect(isColumnEditable('filename'), isFalse);
      });

      test('bitrate is not editable', () {
        expect(isColumnEditable('bitrate'), isFalse);
      });

      test('duration is not editable', () {
        expect(isColumnEditable('duration'), isFalse);
      });

      test('relativePath is not editable', () {
        expect(isColumnEditable('relativePath'), isFalse);
      });
    });

    group('editable columns return true', () {
      test('title is editable', () {
        expect(isColumnEditable('title'), isTrue);
      });

      test('artist is editable', () {
        expect(isColumnEditable('artist'), isTrue);
      });

      test('album is editable', () {
        expect(isColumnEditable('album'), isTrue);
      });

      test('year is editable', () {
        expect(isColumnEditable('year'), isTrue);
      });

      test('genre is editable', () {
        expect(isColumnEditable('genre'), isTrue);
      });

      test('trackNumber is editable', () {
        expect(isColumnEditable('trackNumber'), isTrue);
      });

      test('comment is editable', () {
        expect(isColumnEditable('comment'), isTrue);
      });
    });
  });

  group('nextEditableColumn', () {
    final visibleColumns = [
      'tagIndicator',
      'title',
      'artist',
      'album',
      'filename',
      'genre',
    ];

    test('middle of row returns next editable column in same row', () {
      final current = const CellCoordinate(rowIndex: 0, columnId: 'title');
      final result = nextEditableColumn(current, visibleColumns, 5);

      expect(
        result,
        const CellCoordinate(rowIndex: 0, columnId: 'artist'),
      );
    });

    test('end of row wraps to first editable column of next row', () {
      final current = const CellCoordinate(rowIndex: 0, columnId: 'genre');
      final result = nextEditableColumn(current, visibleColumns, 5);

      expect(
        result,
        const CellCoordinate(rowIndex: 1, columnId: 'title'),
      );
    });

    test('last row last column returns null', () {
      final current = const CellCoordinate(rowIndex: 4, columnId: 'genre');
      final result = nextEditableColumn(current, visibleColumns, 5);

      expect(result, isNull);
    });

    test('single editable column wraps to next row same column', () {
      final singleEditableColumns = [
        'tagIndicator',
        'title',
        'filename',
      ];
      final current = const CellCoordinate(rowIndex: 0, columnId: 'title');
      final result = nextEditableColumn(current, singleEditableColumns, 3);

      expect(
        result,
        const CellCoordinate(rowIndex: 1, columnId: 'title'),
      );
    });

    test('returns null when no editable columns exist', () {
      final readOnlyColumns = ['tagIndicator', 'filename', 'bitrate'];
      final current = const CellCoordinate(rowIndex: 0, columnId: 'title');
      final result = nextEditableColumn(current, readOnlyColumns, 5);

      expect(result, isNull);
    });
  });

  group('previousEditableColumn', () {
    final visibleColumns = [
      'tagIndicator',
      'title',
      'artist',
      'album',
      'filename',
      'genre',
    ];

    test('middle of row returns previous editable column in same row', () {
      final current = const CellCoordinate(rowIndex: 0, columnId: 'artist');
      final result = previousEditableColumn(current, visibleColumns, 5);

      expect(
        result,
        const CellCoordinate(rowIndex: 0, columnId: 'title'),
      );
    });

    test('start of row wraps to last editable column of previous row', () {
      final current = const CellCoordinate(rowIndex: 1, columnId: 'title');
      final result = previousEditableColumn(current, visibleColumns, 5);

      expect(
        result,
        const CellCoordinate(rowIndex: 0, columnId: 'genre'),
      );
    });

    test('first row first column returns null', () {
      final current = const CellCoordinate(rowIndex: 0, columnId: 'title');
      final result = previousEditableColumn(current, visibleColumns, 5);

      expect(result, isNull);
    });

    test('returns null when no editable columns exist', () {
      final readOnlyColumns = ['tagIndicator', 'filename', 'bitrate'];
      final current = const CellCoordinate(rowIndex: 0, columnId: 'title');
      final result = previousEditableColumn(current, readOnlyColumns, 5);

      expect(result, isNull);
    });
  });
}
