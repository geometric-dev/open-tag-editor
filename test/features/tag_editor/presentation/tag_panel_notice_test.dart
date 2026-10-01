import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/editor_state_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/tag_edit_panel.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

AudioFile dirty(String path, Map<String, String> tags) => AudioFile(
  path: path,
  filename: path.split('/').last,
  extension: '.mp3',
  fileSize: 1,
  tags: tags,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pumpPanel(
    WidgetTester tester, {
    required List<AudioFile> files,
  }) async {
    final container = ProviderContainer(
      overrides: [
        fileListProvider.overrideWith((ref) => FileListNotifier()),
        selectedFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    container.read(fileListProvider.notifier).addFiles(files);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TagEditPanel())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('multi-file editing notice', () {
    testWidgets('tells the user that clearing a field deletes it', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        files: [
          dirty('/a.mp3', const {'title': 'A'}),
          dirty('/b.mp3', const {'title': 'B'}),
        ],
      );

      expect(
        find.textContaining('clearing a field removes it from every file'),
        findsOneWidget,
      );
    });

    testWidgets('no longer claims empty fields are left alone', (tester) async {
      // The old copy actively misled: clearing a populated field across a
      // selection deletes it from every file.
      await pumpPanel(
        tester,
        files: [
          dirty('/a.mp3', const {'title': 'A'}),
          dirty('/b.mp3', const {'title': 'B'}),
        ],
      );

      expect(find.textContaining('Empty fields'), findsNothing);
    });

    testWidgets('is not shown for a single selected file', (tester) async {
      await pumpPanel(
        tester,
        files: [
          dirty('/a.mp3', const {'title': 'A'}),
        ],
      );

      expect(find.textContaining('clearing a field'), findsNothing);
    });
    testWidgets('with no selection the tab row stays reachable', (
      tester,
    ) async {
      await pumpPanel(tester, files: const []);

      // The panel no longer short-circuits, so the tabs stay reachable
      // without selecting a file -- File Info is exactly the tab you want
      // when deciding what to select.
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Album Art'), findsOneWidget);
      expect(find.text('File Info'), findsOneWidget);
      expect(find.text('No file selected'), findsOneWidget);
    });

    testWidgets('with no selection the Tags tab says so', (tester) async {
      await pumpPanel(tester, files: const []);

      // Guards the failure this change could introduce: fields that render
      // empty and editable but silently do nothing, because the edit command
      // has no target files.
      expect(
        find.text('Select a file to view and edit its tags'),
        findsOneWidget,
      );
    });
  });
}
