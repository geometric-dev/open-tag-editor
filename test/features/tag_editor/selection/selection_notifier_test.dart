import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/selection_provider.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/data_grid/marquee_utils.dart';

void main() {
  group('SelectionNotifier', () {
    late SelectionNotifier notifier;
    final paths = ['a.mp3', 'b.mp3', 'c.mp3', 'd.mp3', 'e.mp3'];

    setUp(() {
      notifier = SelectionNotifier();
    });

    group('moveDown', () {
      test('moves selection to the next row', () {
        notifier.select('b.mp3');
        notifier.moveDown(paths);

        expect(notifier.state.selectedPaths, {'c.mp3'});
        expect(notifier.state.anchorPath, 'c.mp3');
      });

      test('no-op at last row', () {
        notifier.select('e.mp3');
        notifier.moveDown(paths);

        expect(notifier.state.selectedPaths, {'e.mp3'});
        expect(notifier.state.anchorPath, 'e.mp3');
      });

      test('no-op on empty list', () {
        notifier.select('a.mp3');
        notifier.moveDown([]);

        expect(notifier.state.selectedPaths, {'a.mp3'});
      });

      test('selects first row when no anchor exists', () {
        notifier.moveDown(paths);

        expect(notifier.state.selectedPaths, {'a.mp3'});
        expect(notifier.state.anchorPath, 'a.mp3');
      });
    });

    group('moveUp', () {
      test('moves selection to the previous row', () {
        notifier.select('c.mp3');
        notifier.moveUp(paths);

        expect(notifier.state.selectedPaths, {'b.mp3'});
        expect(notifier.state.anchorPath, 'b.mp3');
      });

      test('no-op at first row', () {
        notifier.select('a.mp3');
        notifier.moveUp(paths);

        expect(notifier.state.selectedPaths, {'a.mp3'});
        expect(notifier.state.anchorPath, 'a.mp3');
      });

      test('no-op on empty list', () {
        notifier.select('a.mp3');
        notifier.moveUp([]);

        expect(notifier.state.selectedPaths, {'a.mp3'});
      });

      test('selects first row when no anchor exists', () {
        notifier.moveUp(paths);

        expect(notifier.state.selectedPaths, {'a.mp3'});
        expect(notifier.state.anchorPath, 'a.mp3');
      });
    });

    group('extendDown', () {
      test('adds one row below selection edge', () {
        notifier.select('b.mp3');
        notifier.extendDown(paths);

        expect(notifier.state.selectedPaths, {'b.mp3', 'c.mp3'});
        expect(notifier.state.anchorPath, 'b.mp3');
      });

      test('no-op at last row', () {
        notifier.select('e.mp3');
        notifier.extendDown(paths);

        expect(notifier.state.selectedPaths, {'e.mp3'});
        expect(notifier.state.anchorPath, 'e.mp3');
      });

      test('extends from furthest selected row', () {
        notifier.select('b.mp3');
        notifier.extendDown(paths);
        notifier.extendDown(paths);

        expect(notifier.state.selectedPaths, {'b.mp3', 'c.mp3', 'd.mp3'});
        expect(notifier.state.anchorPath, 'b.mp3');
      });
    });

    group('extendUp', () {
      test('adds one row above selection edge', () {
        notifier.select('c.mp3');
        notifier.extendUp(paths);

        expect(notifier.state.selectedPaths, {'b.mp3', 'c.mp3'});
        expect(notifier.state.anchorPath, 'c.mp3');
      });

      test('no-op at first row', () {
        notifier.select('a.mp3');
        notifier.extendUp(paths);

        expect(notifier.state.selectedPaths, {'a.mp3'});
        expect(notifier.state.anchorPath, 'a.mp3');
      });

      test('extends from topmost selected row', () {
        notifier.select('c.mp3');
        notifier.extendUp(paths);
        notifier.extendUp(paths);

        expect(notifier.state.selectedPaths, {'a.mp3', 'b.mp3', 'c.mp3'});
        expect(notifier.state.anchorPath, 'c.mp3');
      });
    });

    group('extendToStart', () {
      test('selects from anchor to first row', () {
        notifier.select('c.mp3');
        notifier.extendToStart(paths);

        expect(notifier.state.selectedPaths, {'a.mp3', 'b.mp3', 'c.mp3'});
        expect(notifier.state.anchorPath, 'c.mp3');
      });

      test('no-op when anchor is already at first row', () {
        notifier.select('a.mp3');
        notifier.extendToStart(paths);

        expect(notifier.state.selectedPaths, {'a.mp3'});
        expect(notifier.state.anchorPath, 'a.mp3');
      });

      test('no-op on empty list', () {
        notifier.select('a.mp3');
        notifier.extendToStart([]);

        expect(notifier.state.selectedPaths, {'a.mp3'});
      });
    });

    group('extendToEnd', () {
      test('selects from anchor to last row', () {
        notifier.select('c.mp3');
        notifier.extendToEnd(paths);

        expect(notifier.state.selectedPaths, {'c.mp3', 'd.mp3', 'e.mp3'});
        expect(notifier.state.anchorPath, 'c.mp3');
      });

      test('no-op when anchor is already at last row', () {
        notifier.select('e.mp3');
        notifier.extendToEnd(paths);

        expect(notifier.state.selectedPaths, {'e.mp3'});
        expect(notifier.state.anchorPath, 'e.mp3');
      });

      test('no-op on empty list', () {
        notifier.select('a.mp3');
        notifier.extendToEnd([]);

        expect(notifier.state.selectedPaths, {'a.mp3'});
      });
    });

    group('addRangeSelect', () {
      test('adds range from anchor to target to existing selection', () {
        notifier.select('a.mp3');
        // Simulate existing multi-selection by toggling
        notifier.toggleSelect('e.mp3');
        // Now anchor is 'e.mp3', selected: {'a.mp3', 'e.mp3'}
        notifier.addRangeSelect('c.mp3', paths);

        // Should add range from anchor (e.mp3) to target (c.mp3)
        // That's c.mp3, d.mp3, e.mp3 unioned with existing
        expect(notifier.state.selectedPaths, {
          'a.mp3',
          'c.mp3',
          'd.mp3',
          'e.mp3',
        });
        expect(notifier.state.anchorPath, 'e.mp3');
      });

      test('falls back to toggleSelect when no anchor', () {
        notifier.addRangeSelect('b.mp3', paths);

        expect(notifier.state.selectedPaths, {'b.mp3'});
        expect(notifier.state.anchorPath, 'b.mp3');
      });

      test('preserves anchor unchanged', () {
        notifier.select('b.mp3');
        notifier.addRangeSelect('d.mp3', paths);

        expect(notifier.state.anchorPath, 'b.mp3');
      });
    });

    group('replaceSelection', () {
      test('replaces entire selection with given paths', () {
        notifier.select('a.mp3');
        notifier.replaceSelection({'c.mp3', 'd.mp3'});

        expect(notifier.state.selectedPaths, {'c.mp3', 'd.mp3'});
      });

      test('sets anchor to first path when non-empty', () {
        notifier.replaceSelection({'b.mp3', 'c.mp3'});

        expect(notifier.state.anchorPath, isNotNull);
        expect(
          notifier.state.selectedPaths.contains(notifier.state.anchorPath),
          isTrue,
        );
      });

      test('sets anchor to null when empty set provided', () {
        notifier.select('a.mp3');
        notifier.replaceSelection({});

        expect(notifier.state.selectedPaths, isEmpty);
        expect(notifier.state.anchorPath, isNull);
      });
    });

    group('addToSelection', () {
      test('unions given paths with existing selection', () {
        notifier.select('a.mp3');
        notifier.addToSelection({'c.mp3', 'd.mp3'});

        expect(notifier.state.selectedPaths, {'a.mp3', 'c.mp3', 'd.mp3'});
      });

      test('preserves existing anchor', () {
        notifier.select('a.mp3');
        notifier.addToSelection({'c.mp3'});

        expect(notifier.state.anchorPath, 'a.mp3');
      });

      test('does not duplicate already-selected paths', () {
        notifier.select('a.mp3');
        notifier.addToSelection({'a.mp3', 'b.mp3'});

        expect(notifier.state.selectedPaths, {'a.mp3', 'b.mp3'});
      });
    });
  });

  group('SelectionNotifier keyboard paging', () {
    late SelectionNotifier notifier;
    final paths = ['a.mp3', 'b.mp3', 'c.mp3', 'd.mp3', 'e.mp3'];

    setUp(() {
      notifier = SelectionNotifier();
    });

    test('moveHome selects the first row and sets anchor', () {
      notifier.select('d.mp3');
      notifier.moveHome(paths);

      expect(notifier.state.selectedPaths, {'a.mp3'});
      expect(notifier.state.anchorPath, 'a.mp3');
    });

    test('moveEnd selects the last row', () {
      notifier.select('b.mp3');
      notifier.moveEnd(paths);

      expect(notifier.state.selectedPaths, {'e.mp3'});
    });

    test('home/end no-op on empty list', () {
      notifier.moveHome(<String>[]);
      notifier.moveEnd(<String>[]);

      expect(notifier.state.hasSelection, isFalse);
    });

    test('moveByPage clamps at the last row', () {
      notifier.select('d.mp3');
      notifier.moveByPage(paths, 1, 10);

      expect(notifier.state.selectedPaths, {'e.mp3'});
    });

    test('moveByPage negative direction jumps up', () {
      notifier.select('e.mp3');
      notifier.moveByPage(paths, -1, 2);

      expect(notifier.state.selectedPaths, {'c.mp3'});
    });

    test('moveByPage selects first row when nothing is selected', () {
      notifier.moveByPage(paths, 1, 2);

      expect(notifier.state.selectedPaths, {'a.mp3'});
    });

    test('extendByPage extends range from anchor toward the end', () {
      notifier.select('a.mp3');
      notifier.extendByPage(paths, 1, 2);

      expect(notifier.state.selectedPaths, {'a.mp3', 'b.mp3', 'c.mp3'});
      expect(notifier.state.anchorPath, 'a.mp3');
    });

    test('extendByPage clamps at the list edges', () {
      notifier.select('a.mp3');
      notifier.extendByPage(paths, 1, 99);

      expect(notifier.state.selectedPaths.length, 5);
    });
  });

  group('computeMarqueeIntersectedRows', () {
    test('returns correct rows for a rectangle spanning multiple rows', () {
      // Row height 30, marquee from y=10 to y=80
      // Row 0: [0, 30), Row 1: [30, 60), Row 2: [60, 90)
      final result = computeMarqueeIntersectedRows(
        marqueeTop: 10,
        marqueeBottom: 80,
        rowHeight: 30,
        totalRows: 5,
      );

      expect(result, {0, 1, 2});
    });

    test('returns single row when rectangle is within one row', () {
      // Row height 30, marquee from y=5 to y=20 — entirely within row 0
      final result = computeMarqueeIntersectedRows(
        marqueeTop: 5,
        marqueeBottom: 20,
        rowHeight: 30,
        totalRows: 5,
      );

      expect(result, {0});
    });

    test('returns empty set when totalRows is 0', () {
      final result = computeMarqueeIntersectedRows(
        marqueeTop: 10,
        marqueeBottom: 80,
        rowHeight: 30,
        totalRows: 0,
      );

      expect(result, isEmpty);
    });

    test('handles inverted top/bottom (marqueeTop > marqueeBottom)', () {
      // The function should handle the case where top > bottom
      final result = computeMarqueeIntersectedRows(
        marqueeTop: 80,
        marqueeBottom: 10,
        rowHeight: 30,
        totalRows: 5,
      );

      expect(result, {0, 1, 2});
    });

    test('clamps to valid row indices', () {
      // Marquee extends beyond the total rows
      final result = computeMarqueeIntersectedRows(
        marqueeTop: 0,
        marqueeBottom: 500,
        rowHeight: 30,
        totalRows: 3,
      );

      // Should clamp to rows 0, 1, 2 (max index is 2)
      expect(result, {0, 1, 2});
    });

    test('handles marquee starting at exact row boundary', () {
      // Row height 30, marquee from y=30 to y=60 — exactly row 1
      final result = computeMarqueeIntersectedRows(
        marqueeTop: 30,
        marqueeBottom: 60,
        rowHeight: 30,
        totalRows: 5,
      );

      expect(result, {1, 2});
    });

    test('handles negative marquee coordinates by clamping', () {
      final result = computeMarqueeIntersectedRows(
        marqueeTop: -10,
        marqueeBottom: 25,
        rowHeight: 30,
        totalRows: 5,
      );

      expect(result, {0});
    });
  });

  group('SelectionNotifier folder selection', () {
    late SelectionNotifier notifier;
    // Layout: Folder 1 has [f1, f2], Folder 2 has [f3, f4], Folder 3 has [f5, f6]
    final orderedPaths = [
      'f1.mp3',
      'f2.mp3',
      'f3.mp3',
      'f4.mp3',
      'f5.mp3',
      'f6.mp3',
    ];
    final folder1 = ['f1.mp3', 'f2.mp3'];
    final folder2 = ['f3.mp3', 'f4.mp3'];
    final folder3 = ['f5.mp3', 'f6.mp3'];

    setUp(() {
      notifier = SelectionNotifier();
    });

    test('selectFolder selects all files in the folder group', () {
      notifier.selectFolder(folder2);

      expect(notifier.state.selectedPaths, {'f3.mp3', 'f4.mp3'});
      expect(notifier.state.anchorPath, 'f3.mp3');
      expect(notifier.state.activePath, 'f4.mp3');
      expect(notifier.state.anchorGroup, folder2);
    });

    test('toggleSelectFolder adds folder files when unselected', () {
      notifier.select('f1.mp3');
      notifier.toggleSelectFolder(folder2);

      expect(notifier.state.selectedPaths, {'f1.mp3', 'f3.mp3', 'f4.mp3'});
    });

    test('toggleSelectFolder removes folder files when all are selected', () {
      notifier.selectFolder(folder2);
      notifier.toggleSelectFolder(folder2);

      expect(notifier.state.selectedPaths, isEmpty);
    });

    test(
      'toggleSelectFolder selects all folder files when partially selected',
      () {
        notifier.select('f3.mp3');
        notifier.toggleSelectFolder(folder2);

        expect(notifier.state.selectedPaths, {'f3.mp3', 'f4.mp3'});
      },
    );

    test(
      'rangeSelectFolder forward selects from anchor through all folder subfiles',
      () {
        // User clicks f1 in Folder 1, then Shift-clicks Folder 2
        notifier.select('f1.mp3');
        notifier.rangeSelectFolder(folder2, orderedPaths);

        // Should select f1, f2, and ALL of folder 2 (f3, f4)
        expect(notifier.state.selectedPaths, {
          'f1.mp3',
          'f2.mp3',
          'f3.mp3',
          'f4.mp3',
        });
        expect(notifier.state.anchorPath, 'f1.mp3');
        expect(notifier.state.activePath, 'f4.mp3');
      },
    );

    test(
      'rangeSelectFolder backward selects from folder start through anchor',
      () {
        // User clicks f6 in Folder 3, then Shift-clicks Folder 2
        notifier.select('f6.mp3');
        notifier.rangeSelectFolder(folder2, orderedPaths);

        // Should select from f3 (start of Folder 2) through f6
        expect(notifier.state.selectedPaths, {
          'f3.mp3',
          'f4.mp3',
          'f5.mp3',
          'f6.mp3',
        });
        expect(notifier.state.anchorPath, 'f6.mp3');
        expect(notifier.state.activePath, 'f4.mp3');
      },
    );

    test(
      'rangeSelectFolder between folders selects both folders and intervening files',
      () {
        // User clicks Folder 1, then Shift-clicks Folder 3
        notifier.selectFolder(folder1);
        notifier.rangeSelectFolder(folder3, orderedPaths);

        // All files from Folder 1 through Folder 3 should be selected
        expect(notifier.state.selectedPaths, orderedPaths.toSet());
      },
    );

    test('rangeSelect from folder anchor backward preserves entire folder', () {
      // User clicks Folder 2 (f3, f4), then Shift-clicks f1
      notifier.selectFolder(folder2);
      notifier.rangeSelect('f1.mp3', orderedPaths);

      // Should include f1, f2, f3, and f4
      expect(notifier.state.selectedPaths, {
        'f1.mp3',
        'f2.mp3',
        'f3.mp3',
        'f4.mp3',
      });
    });

    test('rangeSelect from folder anchor forward preserves entire folder', () {
      // User clicks Folder 2 (f3, f4), then Shift-clicks f6
      notifier.selectFolder(folder2);
      notifier.rangeSelect('f6.mp3', orderedPaths);

      // Should include f3, f4, f5, and f6
      expect(notifier.state.selectedPaths, {
        'f3.mp3',
        'f4.mp3',
        'f5.mp3',
        'f6.mp3',
      });
    });

    test('addRangeSelectFolder unions range with existing selection', () {
      notifier.select('f1.mp3');
      // Set anchor at f3
      notifier.toggleSelect('f3.mp3');
      notifier.addRangeSelectFolder(folder3, orderedPaths);

      // Should retain f1, and add range f3..f6
      expect(notifier.state.selectedPaths, {
        'f1.mp3',
        'f3.mp3',
        'f4.mp3',
        'f5.mp3',
        'f6.mp3',
      });
    });
  });
}
