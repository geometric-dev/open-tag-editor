import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/settings/data/models/general_settings.dart';
import 'package:open_tag_editor/features/settings/data/notifiers/general_settings_notifier.dart';
import 'package:open_tag_editor/features/settings/data/providers/settings_providers.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/widgets/save_confirmation.dart';
import 'package:shared_preferences/shared_preferences.dart';

AudioFile dirtyFile(String path) => AudioFile(
  path: path,
  filename: path.split('/').last,
  extension: '.mp3',
  fileSize: 1,
  tags: const {'title': 'new'},
  originalTags: const {'title': 'old'},
  isModified: true,
);

/// Pumps a host whose "save" button calls SaveConfirmation and records the
/// answer, so the dialog's real pop value can be observed.
Future<List<bool>> pumpHost(
  WidgetTester tester, {
  required bool confirmBeforeSave,
  required List<AudioFile> files,
}) async {
  final answers = <bool>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        generalSettingsProvider.overrideWith(
          (ref) => GeneralSettingsNotifier(),
        ),
        fileListProvider.overrideWith((ref) => FileListNotifier()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Consumer(
              builder: (context, ref, _) {
                return TextButton(
                  onPressed: () async {
                    final ok = await SaveConfirmation.confirmIfNeeded(
                      context: context,
                      ref: ref,
                    );
                    answers.add(ok);
                  },
                  child: const Text('save'),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  // Seed the providers.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Consumer)),
  );
  container.read(generalSettingsProvider.notifier).state = GeneralSettings(
    confirmBeforeSave: confirmBeforeSave,
  );
  container.read(fileListProvider.notifier).addFiles(files);

  return answers;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('does not prompt when the setting is off', (tester) async {
    final answers = await pumpHost(
      tester,
      confirmBeforeSave: false,
      files: [dirtyFile('/a.mp3')],
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(answers, [true]);
  });

  testWidgets('prompts when the setting is on', (tester) async {
    await pumpHost(
      tester,
      confirmBeforeSave: true,
      files: [dirtyFile('/a.mp3')],
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('1 file(s)'), findsOneWidget);
  });

  testWidgets('Save returns true', (tester) async {
    final answers = await pumpHost(
      tester,
      confirmBeforeSave: true,
      files: [dirtyFile('/a.mp3')],
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(answers, [true]);
  });

  testWidgets('Cancel returns false', (tester) async {
    final answers = await pumpHost(
      tester,
      confirmBeforeSave: true,
      files: [dirtyFile('/a.mp3')],
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });

  testWidgets('dismissing the dialog is a cancel, not a save', (tester) async {
    final answers = await pumpHost(
      tester,
      confirmBeforeSave: true,
      files: [dirtyFile('/a.mp3')],
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    // Tap the barrier to dismiss.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });

  testWidgets('does not prompt when nothing is modified', (tester) async {
    final answers = await pumpHost(
      tester,
      confirmBeforeSave: true,
      files: const [
        AudioFile(
          path: '/clean.mp3',
          filename: 'clean.mp3',
          extension: '.mp3',
          fileSize: 1,
        ),
      ],
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(answers, [true]);
  });

  testWidgets('reports the real modified-file count', (tester) async {
    await pumpHost(
      tester,
      confirmBeforeSave: true,
      files: [dirtyFile('/a.mp3'), dirtyFile('/b.mp3')],
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 file(s)'), findsOneWidget);
  });
}
