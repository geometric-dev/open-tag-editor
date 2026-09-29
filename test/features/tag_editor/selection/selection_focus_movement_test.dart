import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/selection_provider.dart';

void main() {
  late SelectionNotifier notifier;
  const paths = ['/a', '/b', '/c', '/d'];

  setUp(() {
    notifier = SelectionNotifier();
  });

  group('Ctrl+Arrow focus movement', () {
    test('moves focus down without changing the selection', () {
      notifier.select('/a');
      expect(notifier.state.selectedPaths, {'/a'});

      notifier.moveFocusDown(paths);

      expect(notifier.state.activePath, '/b');
      // The whole point: the selection is untouched.
      expect(notifier.state.selectedPaths, {'/a'});
    });

    test('moves focus up without changing the selection', () {
      notifier.select('/c');
      notifier.moveFocusUp(paths);

      expect(notifier.state.activePath, '/b');
      expect(notifier.state.selectedPaths, {'/c'});
    });

    test('clamps at the last row', () {
      notifier.select('/d');
      notifier.moveFocusDown(paths);

      expect(notifier.state.activePath, '/d');
    });

    test('clamps at the first row', () {
      notifier.select('/a');
      notifier.moveFocusUp(paths);

      expect(notifier.state.activePath, '/a');
    });

    test('repeated moves walk the whole list', () {
      notifier.select('/a');
      notifier
        ..moveFocusDown(paths)
        ..moveFocusDown(paths)
        ..moveFocusDown(paths);

      expect(notifier.state.activePath, '/d');
      expect(notifier.state.selectedPaths, {'/a'});
    });

    test('no-op on an empty list', () {
      notifier.select('/a');
      notifier.moveFocusDown(const []);

      expect(notifier.state.activePath, '/a');
    });

    test('focuses the first row when nothing is active yet', () {
      notifier.moveFocusDown(paths);

      expect(notifier.state.activePath, '/a');
    });

    test('focuses the last row when moving up with nothing active', () {
      notifier.moveFocusUp(paths);

      expect(notifier.state.activePath, '/d');
    });

    test('a multi-row selection survives focus movement intact', () {
      notifier.select('/a');
      notifier.extendDown(paths);
      expect(notifier.state.selectedPaths, {'/a', '/b'});

      notifier.moveFocusDown(paths);

      expect(notifier.state.selectedPaths, {'/a', '/b'});
      expect(notifier.state.activePath, '/c');
    });
  });

  group('Ctrl+Space toggling', () {
    test('adds the focused row to the selection', () {
      notifier.select('/a');
      notifier.moveFocusDown(paths);

      notifier.toggleActivePathSelection();

      expect(notifier.state.selectedPaths, containsAll(['/a', '/b']));
    });

    test('removes an already-selected row', () {
      notifier.select('/b');

      notifier.toggleActivePathSelection();

      expect(notifier.state.selectedPaths, isEmpty);
    });

    test('is a no-op when there is no active row', () {
      notifier.toggleActivePathSelection();

      expect(notifier.state.selectedPaths, isEmpty);
    });

    test('toggling off the only selected row leaves nothing selected', () {
      notifier.select('/a');

      notifier.toggleActivePathSelection();

      expect(notifier.state.hasSelection, isFalse);
    });
  });

  group('focus movement interaction with existing navigation', () {
    test('focus movement does not move the anchor', () {
      notifier.select('/a');
      notifier.moveFocusDown(paths);

      // The anchor must stay put, otherwise a later Shift+click would
      // select a range from the wrong row.
      expect(notifier.state.anchorPath, '/a');
    });

    test('plain arrow movement still collapses the selection', () {
      notifier.select('/a');
      notifier.moveDown(paths);

      expect(notifier.state.selectedPaths, {'/b'});
      expect(notifier.state.activePath, '/b');
    });
  });
}
