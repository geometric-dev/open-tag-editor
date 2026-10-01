import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/selection_provider.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/data_grid/file_row_context_menu.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile file(String path, {bool isModified = false}) => AudioFile(
  path: path,
  filename: path.split('/').last,
  extension: '.mp3',
  fileSize: 1,
  tags: const {'title': 'T'},
  originalTags: const {'title': 'T'},
  isModified: isModified,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [fileListProvider.overrideWith((ref) => FileListNotifier())],
    );
    addTearDown(container.dispose);
  });

  // A WidgetRef backed by the same container, so the static helper can be
  // exercised outside a real widget tree.
  testWidgets('offers the row actions', (tester) async {
    container.read(fileListProvider.notifier).addFiles([
      file('/a.mp3'),
      file('/b.mp3'),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async {
                    await FileRowContextMenu.show(
                      context,
                      ref,
                      rowPath: '/a.mp3',
                      position: Offset.zero,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Edit tags'), findsOneWidget);
    expect(find.text('Refresh from disk'), findsOneWidget);
    // Only the clicked row is selected, so this is the singular form.
    expect(find.text('Remove from list'), findsOneWidget);
  });

  testWidgets('right-clicking an unselected row selects it first', (
    tester,
  ) async {
    container.read(fileListProvider.notifier).addFiles([
      file('/a.mp3'),
      file('/b.mp3'),
    ]);
    container.read(selectionProvider.notifier).select('/a.mp3');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async {
                    await FileRowContextMenu.show(
                      context,
                      ref,
                      rowPath: '/b.mp3',
                      position: Offset.zero,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The menu describes the row that was clicked, not the previous selection.
    expect(find.text('Remove from list'), findsOneWidget);
    expect(container.read(selectionProvider).selectedPaths, {'/b.mp3'});
  });

  testWidgets('acts on the whole selection, pluralised', (tester) async {
    container.read(fileListProvider.notifier).addFiles([
      file('/a.mp3'),
      file('/b.mp3'),
      file('/c.mp3'),
    ]);
    container.read(selectionProvider.notifier).selectAll([
      '/a.mp3',
      '/b.mp3',
      '/c.mp3',
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async {
                    await FileRowContextMenu.show(
                      context,
                      ref,
                      rowPath: '/b.mp3',
                      position: Offset.zero,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The row is already part of the selection, so the selection is kept.
    expect(find.text('Remove 3 file(s) from list'), findsOneWidget);
    expect(container.read(selectionProvider).selectedPaths, {
      '/a.mp3',
      '/b.mp3',
      '/c.mp3',
    });
  });

  testWidgets('save is disabled when nothing is modified', (tester) async {
    container.read(fileListProvider.notifier).addFiles([file('/a.mp3')]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async {
                    await FileRowContextMenu.show(
                      context,
                      ref,
                      rowPath: '/a.mp3',
                      position: Offset.zero,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final item = tester.widget<PopupMenuItem<FileRowAction>>(
      find.widgetWithText(PopupMenuItem<FileRowAction>, 'Save this file'),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('save is enabled and pluralised for modified files', (
    tester,
  ) async {
    container.read(fileListProvider.notifier).addFiles([
      file('/a.mp3', isModified: true),
      file('/b.mp3', isModified: true),
    ]);
    container.read(selectionProvider.notifier).selectAll(['/a.mp3', '/b.mp3']);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async {
                    await FileRowContextMenu.show(
                      context,
                      ref,
                      rowPath: '/a.mp3',
                      position: Offset.zero,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final item = tester.widget<PopupMenuItem<FileRowAction>>(
      find.widgetWithText(
        PopupMenuItem<FileRowAction>,
        'Save 2 modified file(s)',
      ),
    );
    expect(item.enabled, isTrue);
  });
}
