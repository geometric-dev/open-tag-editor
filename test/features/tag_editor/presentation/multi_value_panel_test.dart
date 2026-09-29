import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/editor_state_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/tag_edit_panel.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

AudioFile file(Map<String, String> tags) => AudioFile(
  path: '/a.mp3',
  filename: 'a.mp3',
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
    required Map<String, String> tags,
  }) async {
    final container = ProviderContainer(
      overrides: [
        fileListProvider.overrideWith((ref) => FileListNotifier()),
        selectedFilesProvider.overrideWithValue([file(tags)]),
      ],
    );
    addTearDown(container.dispose);
    container.read(fileListProvider.notifier).addFiles([file(tags)]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TagEditPanel())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a multi-value field renders one chip per value', (tester) async {
    await pumpPanel(
      tester,
      tags: const {'artist': 'First Artist; Second Artist'},
    );

    expect(find.text('First Artist'), findsOneWidget);
    expect(find.text('Second Artist'), findsOneWidget);
  });

  testWidgets('a single-value field keeps its text field', (tester) async {
    await pumpPanel(tester, tags: const {'album': 'One Album'});

    // The album field is not multi-value, so it must not render chips.
    expect(find.widgetWithText(InputChip, 'One Album'), findsNothing);
  });

  testWidgets('a multi-value field reports its value count', (tester) async {
    await pumpPanel(tester, tags: const {'genre': 'Rock; Jazz'});

    expect(find.text('2 values'), findsOneWidget);
  });

  testWidgets('a multi-value field with no values says so', (tester) async {
    await pumpPanel(tester, tags: const {});

    // Every multi-value field reports empty, not just the first, so this
    // deliberately does not pin a count that would break when a field is
    // added to or removed from the multi-value set.
    expect(find.text('No values'), findsWidgets);
  });

  testWidgets('deleting a chip commits the new value set', (tester) async {
    final container = await pumpPanel(
      tester,
      tags: const {'artist': 'First; Second'},
    );

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Second'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    final stored = container.read(fileListProvider).first.tags['artist'];
    expect(stored, 'First');
  });

  testWidgets('an inline add field sits next to the chips', (tester) async {
    await pumpPanel(tester, tags: const {'artist': 'First'});

    // The hint lives in the InputDecoration rather than as a child Text, so
    // match on the decoration itself.
    final addFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((f) => f.decoration?.hintText == 'Add value…');
    expect(addFields, isNotEmpty);
  });
}
