import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tools/presentation/clear_fields_dialog.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile file(String path, Map<String, String> tags) {
  return AudioFile(
    path: path,
    filename: path.split('/').last,
    extension: '.mp3',
    fileSize: 1,
    tags: tags,
  );
}

/// Holds whatever the dialog popped, readable after it is dismissed.
class PoppedSelection {
  Set<String>? value;
}

/// Opens the dialog for [files] and returns a holder for its result.
Future<PoppedSelection> pumpDialog(
  WidgetTester tester,
  List<AudioFile> files,
) async {
  final result = PoppedSelection();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result.value = await ClearFieldsDialog.show(
                context,
                files: files,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

List<CheckboxListTile> tiles(WidgetTester tester) =>
    tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();

Finder tileFinder(String label) => find.widgetWithText(CheckboxListTile, label);

bool? tileValue(WidgetTester tester, String label) =>
    tester.widget<CheckboxListTile>(tileFinder(label)).value;

void main() {
  testWidgets('lists only fields present in the selection', (tester) async {
    await pumpDialog(tester, [
      file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
    ]);

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Artist'), findsOneWidget);
    expect(find.text('Album'), findsNothing);
  });

  testWidgets('pre-checks fields present on every file', (tester) async {
    await pumpDialog(tester, [
      file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      file('/b.mp3', const {'title': 'U'}),
    ]);

    expect(tileValue(tester, 'Title'), isTrue);
    // A partial field starts unchecked so Select All stays deliberate.
    expect(tileValue(tester, 'Artist'), isFalse);
  });

  testWidgets('marks partial fields with a count', (tester) async {
    await pumpDialog(tester, [
      file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      file('/b.mp3', const {'title': 'U'}),
    ]);

    expect(find.text('in 1 of 2 files'), findsOneWidget);
    expect(find.text('in all 2 files'), findsOneWidget);
  });

  testWidgets('Select All checks every listed field', (tester) async {
    await pumpDialog(tester, [
      file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      file('/b.mp3', const {'title': 'U'}),
    ]);

    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    expect(tiles(tester).every((c) => c.value == true), isTrue);
  });

  testWidgets('Select None unchecks everything and disables Clear', (
    tester,
  ) async {
    await pumpDialog(tester, [
      file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
    ]);

    await tester.tap(find.text('Select None'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clear'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('affected-file preview tracks the selection', (tester) async {
    await pumpDialog(tester, [
      file('/a.mp3', const {'title': 'T'}),
      file('/b.mp3', const {'title': 'U', 'artist': 'A'}),
    ]);

    // Title is pre-checked (present on both files).
    expect(find.text('2 file(s) affected'), findsOneWidget);

    // Adding the partial Artist field still affects both files.
    await tester.tap(tileFinder('Artist'));
    await tester.pumpAndSettle();
    expect(find.text('2 file(s) affected'), findsOneWidget);

    // Dropping Title leaves only Artist, which only /b.mp3 carries.
    await tester.tap(tileFinder('Title'));
    await tester.pumpAndSettle();
    expect(find.text('1 file(s) affected'), findsOneWidget);

    await tester.tap(find.text('Select None'));
    await tester.pumpAndSettle();
    expect(find.text('0 file(s) affected'), findsOneWidget);
  });

  testWidgets('an empty selection shows a placeholder', (tester) async {
    await pumpDialog(tester, const []);

    expect(find.text('No tag fields to clear'), findsOneWidget);
  });

  testWidgets('cancelling pops with null', (tester) async {
    final popped = await pumpDialog(tester, [
      file('/a.mp3', const {'title': 'T'}),
    ]);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(popped.value, isNull);
  });

  testWidgets('confirming pops with the checked fields', (tester) async {
    final popped = await pumpDialog(tester, [
      file('/a.mp3', const {'title': 'T'}),
      file('/b.mp3', const {'title': 'U', 'artist': 'A'}),
    ]);

    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(popped.value, {'title', 'artist'});
  });
}
