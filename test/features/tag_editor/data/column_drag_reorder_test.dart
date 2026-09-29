import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/column_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('moveColumn (drag convention)', () {
    late ColumnConfigNotifier notifier;

    setUp(() {
      notifier = ColumnConfigNotifier();
    });

    test('moves a column to a later position', () {
      final before = notifier.state.visibleColumnIds;

      // Drag index 2 to index 4, in the post-removal coordinate space.
      notifier.moveColumn(2, 4);

      final after = notifier.state.visibleColumnIds;
      expect(after, hasLength(before.length));
      expect(after[4], before[2], reason: 'landed at the requested index');
      // The columns it displaced shift back by one.
      expect(after[2], before[3]);
      expect(after[3], before[4]);
    });

    test('moves a column to the very end', () {
      final before = notifier.state.visibleColumnIds;

      notifier.moveColumn(2, before.length - 1);

      expect(notifier.state.visibleColumnIds.last, before[2]);
    });

    test('moves a column to an earlier position', () {
      final before = notifier.state.visibleColumnIds;

      notifier.moveColumn(3, 1);

      final after = notifier.state.visibleColumnIds;
      expect(after[1], before[3]);
    });

    test('refuses to drop a column before the fixed first column', () {
      final before = notifier.state.visibleColumnIds;

      notifier.moveColumn(2, 0);

      expect(notifier.state.visibleColumnIds, before);
    });

    test('allows index 1, just after the fixed column', () {
      final before = notifier.state.visibleColumnIds;

      notifier.moveColumn(3, 1);

      expect(notifier.state.visibleColumnIds[1], before[3]);
    });

    test('a no-op move leaves the order untouched', () {
      final before = notifier.state.visibleColumnIds;

      notifier.moveColumn(2, 2);

      expect(notifier.state.visibleColumnIds, before);
    });

    test('ignores out-of-range indices', () {
      final before = notifier.state.visibleColumnIds;

      notifier
        ..moveColumn(-1, 2)
        ..moveColumn(99, 2)
        ..moveColumn(2, 99);

      expect(notifier.state.visibleColumnIds, before);
    });

    test('keeps the full order list in sync', () {
      final orderBefore = notifier.state.columnOrder;
      final visibleBefore = notifier.state.visibleColumnIds;

      notifier.moveColumn(2, 4);

      // The order list holds visible + hidden ids, so a visible move must
      // not drop or duplicate an id in it.
      expect(notifier.state.columnOrder, hasLength(orderBefore.length));
      expect(
        notifier.state.columnOrder.toSet(),
        orderBefore.toSet(),
        reason: 'no id lost or invented',
      );
      expect(
        notifier.state.visibleColumnIds.toSet().difference(
          notifier.state.columnOrder.toSet(),
        ),
        isEmpty,
        reason: 'every visible id is still in the order list',
      );
      expect(visibleBefore.toSet(), notifier.state.visibleColumnIds.toSet());
    });

    test('a column is never lost across repeated moves', () {
      final before = notifier.state.visibleColumnIds.toSet();

      notifier
        ..moveColumn(2, 5)
        ..moveColumn(4, 1)
        ..moveColumn(0, 3);

      expect(notifier.state.visibleColumnIds.toSet(), before);
      expect(
        notifier.state.visibleColumnIds.toSet().length,
        notifier.state.visibleColumnIds.length,
        reason: 'no duplicates',
      );
    });
  });

  group('reorderColumn (menu convention) still works', () {
    test('Move Right swaps with the next column', () {
      final notifier = ColumnConfigNotifier();
      final before = notifier.state.visibleColumnIds;

      notifier.reorderColumn(1, 2);

      final after = notifier.state.visibleColumnIds;
      expect(after[1], before[2]);
      expect(after[2], before[1]);
    });
  });
}
