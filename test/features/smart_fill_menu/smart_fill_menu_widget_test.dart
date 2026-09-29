import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/undo/undo_redo_manager.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/filtered_sorted_file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/selection_provider.dart';
import 'package:open_tag_editor/features/tag_editor/inline_cell_editing/models/cell_coordinate.dart';
import 'package:open_tag_editor/features/tag_editor/inline_cell_editing/providers/inline_cell_edit_provider.dart';
import 'package:open_tag_editor/features/tag_editor/inline_cell_editing/widgets/editable_cell.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

void main() {
  final testFiles = [
    const AudioFile(
      path: '/music/song1.mp3',
      filename: 'song1.mp3',
      extension: '.mp3',
      fileSize: 1024,
      tags: {'genre': 'Rock', 'artist': 'Band A', 'title': 'Song One'},
    ),
    const AudioFile(
      path: '/music/song2.mp3',
      filename: 'song2.mp3',
      extension: '.mp3',
      fileSize: 2048,
      tags: {'genre': 'Pop', 'artist': 'Band B', 'title': 'Song Two'},
    ),
    const AudioFile(
      path: '/music/song3.mp3',
      filename: 'song3.mp3',
      extension: '.mp3',
      fileSize: 3072,
      tags: {'genre': 'Jazz', 'artist': 'Band C', 'title': 'Song Three'},
    ),
  ];

  Widget buildTestWidget({
    required List<AudioFile> files,
    CellCoordinate? coordinate,
    String value = 'Rock',
    double width = 200,
    bool isModified = false,
    Set<String> selectedPaths = const {},
  }) {
    final coord =
        coordinate ?? const CellCoordinate(columnId: 'genre', rowIndex: 0);
    return ProviderScope(
      overrides: [
        fileListProvider.overrideWith((ref) {
          final notifier = FileListNotifier();
          notifier.addFiles(files);
          return notifier;
        }),
        filteredSortedFileListProvider.overrideWithValue(files),
        selectionProvider.overrideWith((ref) {
          final notifier = SelectionNotifier();
          if (selectedPaths.isNotEmpty) {
            notifier.replaceSelection(selectedPaths);
          }
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: EditableCell(
              coordinate: coord,
              value: value,
              width: width,
              isModified: isModified,
            ),
          ),
        ),
      ),
    );
  }

  /// Helper to hover over the cell and tap the fill arrow to open the menu.
  Future<TestGesture> openFillMenu(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byType(EditableCell)));
    await tester.pump();

    // Tap the arrow to open the menu.
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    // Pump enough frames for the popup route animation to complete.
    // The popup menu route animation is 300ms but IgnorePointer
    // is only disabled after the animation fully completes.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    return gesture;
  }

  /// Helper to tap a popup menu item by its label text.
  Future<void> tapMenuItem(WidgetTester tester, String text) async {
    final menuItem = find.text(text);
    await tester.tap(menuItem, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  group('5.1 Fill arrow visibility and interaction', () {
    testWidgets('fill arrow appears on hover', (tester) async {
      await tester.pumpWidget(buildTestWidget(files: testFiles));

      // Verify no arrow initially.
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

      // Hover over the cell.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(EditableCell)));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      await gesture.removePointer();
    });

    testWidgets('fill arrow hides on hover exit', (tester) async {
      await tester.pumpWidget(buildTestWidget(files: testFiles));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(EditableCell)));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      // Move pointer away from the cell.
      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

      await gesture.removePointer();
    });

    testWidgets('fill arrow hidden during edit mode', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(files: testFiles, selectedPaths: {testFiles[0].path}),
      );

      // Enter edit mode via the provider.
      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(EditableCell)),
      );
      providerContainer
          .read(inlineCellEditProvider.notifier)
          .enterEditMode(
            const CellCoordinate(columnId: 'genre', rowIndex: 0),
            prePopulate: true,
          );
      await tester.pump();

      // Hover over the cell.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(EditableCell)));
      await tester.pump();

      // Arrow should NOT appear during edit mode.
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

      await gesture.removePointer();
    });

    testWidgets('fill arrow hidden on read-only columns', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          files: testFiles,
          coordinate: const CellCoordinate(columnId: 'filename', rowIndex: 0),
          value: 'song1.mp3',
        ),
      );

      // Hover over the cell.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(EditableCell)));
      await tester.pump();

      // Arrow should NOT appear on read-only columns.
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

      await gesture.removePointer();
    });

    testWidgets('click fill arrow does not trigger edit mode', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(files: testFiles, selectedPaths: {testFiles[0].path}),
      );

      // Hover to show the arrow.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(EditableCell)));
      await tester.pump();

      // Click the fill arrow.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify edit mode was NOT entered.
      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(EditableCell)),
      );
      final editState = providerContainer.read(inlineCellEditProvider);
      expect(editState.editingCell, isNull);

      await gesture.removePointer();
    });

    testWidgets('menu opens on fill arrow click', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(files: testFiles, selectedPaths: {testFiles[0].path}),
      );

      final gesture = await openFillMenu(tester);

      // Verify popup menu items appear via their text labels.
      // With 1 selected out of 3, labels use "Set selected to".
      expect(find.text('Set selected to Rock'), findsOneWidget);
      expect(find.text('Set selected to Pop'), findsOneWidget);
      expect(find.text('Set selected to Jazz'), findsOneWidget);
      expect(find.text('Set selected to blank'), findsOneWidget);

      await gesture.removePointer();
    });
  });

  group('5.2 Fill action and undo/redo', () {
    testWidgets('fill action creates TagEditCommand and updates file', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(files: testFiles, selectedPaths: {testFiles[0].path}),
      );

      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(EditableCell)),
      );

      final gesture = await openFillMenu(tester);

      // Tap the "Pop" menu item.
      await tapMenuItem(tester, 'Set selected to Pop');

      // Verify the file's genre was updated.
      final files = providerContainer.read(fileListProvider);
      final updatedFile = files.firstWhere((f) => f.path == '/music/song1.mp3');
      expect(updatedFile.tags['genre'], 'Pop');

      // Verify a command was added to the undo stack.
      final undoState = providerContainer.read(undoRedoProvider);
      expect(undoState.canUndo, isTrue);

      await gesture.removePointer();
    });

    testWidgets('Ctrl+Z undoes fill action', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(files: testFiles, selectedPaths: {testFiles[0].path}),
      );

      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(EditableCell)),
      );

      final gesture = await openFillMenu(tester);

      // Apply fill with "Pop".
      await tapMenuItem(tester, 'Set selected to Pop');

      // Verify the change was applied.
      var files = providerContainer.read(fileListProvider);
      expect(
        files.firstWhere((f) => f.path == '/music/song1.mp3').tags['genre'],
        'Pop',
      );

      // Undo via the provider.
      providerContainer.read(undoRedoProvider.notifier).undo();
      await tester.pump();

      // Verify the value was reverted.
      files = providerContainer.read(fileListProvider);
      expect(
        files.firstWhere((f) => f.path == '/music/song1.mp3').tags['genre'],
        'Rock',
      );

      await gesture.removePointer();
    });

    testWidgets('Ctrl+Y redoes fill action', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(files: testFiles, selectedPaths: {testFiles[0].path}),
      );

      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(EditableCell)),
      );

      final gesture = await openFillMenu(tester);

      // Apply fill with "Pop".
      await tapMenuItem(tester, 'Set selected to Pop');

      // Undo.
      providerContainer.read(undoRedoProvider.notifier).undo();
      await tester.pump();

      // Verify undone.
      var files = providerContainer.read(fileListProvider);
      expect(
        files.firstWhere((f) => f.path == '/music/song1.mp3').tags['genre'],
        'Rock',
      );

      // Redo.
      providerContainer.read(undoRedoProvider.notifier).redo();
      await tester.pump();

      // Verify re-applied.
      files = providerContainer.read(fileListProvider);
      expect(
        files.firstWhere((f) => f.path == '/music/song1.mp3').tags['genre'],
        'Pop',
      );

      await gesture.removePointer();
    });

    testWidgets('active edit cancelled before menu opens', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(files: testFiles, selectedPaths: {testFiles[0].path}),
      );

      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(EditableCell)),
      );

      // Enter edit mode on a different cell (artist column).
      // The _openSmartFillMenu method checks for active edits and cancels them.
      providerContainer
          .read(inlineCellEditProvider.notifier)
          .enterEditMode(
            const CellCoordinate(columnId: 'artist', rowIndex: 0),
            prePopulate: true,
          );
      await tester.pump();

      // Verify we are in edit mode on the artist cell.
      expect(
        providerContainer.read(inlineCellEditProvider).editingCell,
        const CellCoordinate(columnId: 'artist', rowIndex: 0),
      );

      // Hover to show the fill arrow on the genre cell.
      // Since we're editing 'artist' not 'genre', the genre cell's arrow
      // should still be visible (isEditing checks widget.coordinate).
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(EditableCell)));
      await tester.pump();

      // The fill arrow should be visible since this cell is not in edit mode.
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      // Click the fill arrow — this triggers _openSmartFillMenu which
      // cancels any active edit before opening the menu.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify edit mode was cancelled.
      final editState = providerContainer.read(inlineCellEditProvider);
      expect(editState.editingCell, isNull);

      await gesture.removePointer();
    });
  });
}
