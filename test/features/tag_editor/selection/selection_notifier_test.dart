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

        expect(
          notifier.state.selectedPaths,
          {'b.mp3', 'c.mp3', 'd.mp3'},
        );
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

        expect(
          notifier.state.selectedPaths,
          {'a.mp3', 'b.mp3', 'c.mp3'},
        );
        expect(notifier.state.anchorPath, 'c.mp3');
      });
    });

    group('extendToStart', () {
      test('selects from anchor to first row', () {
        notifier.select('c.mp3');
        notifier.extendToStart(paths);

        expect(
          notifier.state.selectedPaths,
          {'a.mp3', 'b.mp3', 'c.mp3'},
        );
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

        expect(
          notifier.state.selectedPaths,
          {'c.mp3', 'd.mp3', 'e.mp3'},
        );
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
        expect(
          notifier.state.selectedPaths,
          {'a.mp3', 'c.mp3', 'd.mp3', 'e.mp3'},
        );
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
          notifier.state.selectedPaths
              .contains(notifier.state.anchorPath),
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

        expect(
          notifier.state.selectedPaths,
          {'a.mp3', 'c.mp3', 'd.mp3'},
        );
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
}
