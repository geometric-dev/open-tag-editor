import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tools/data/clear_tags_command.dart';
import 'package:open_tag_editor/features/tools/data/tag_deletion_plan.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile file(
  String path,
  Map<String, String> tags, {
  bool isModified = false,
}) {
  return AudioFile(
    path: path,
    filename: path.split('/').last,
    extension: '.mp3',
    fileSize: 1,
    tags: tags,
    originalTags: Map<String, String>.unmodifiable(tags),
    isModified: isModified,
  );
}

void main() {
  late FileListNotifier notifier;

  setUp(() {
    notifier = FileListNotifier();
  });

  AudioFile byPath(String path) =>
      notifier.currentFiles.firstWhere((f) => f.path == path);

  group('ClearTagsCommand', () {
    test('removes every planned field and marks the file modified', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final plan = planClear(notifier.currentFiles, null);

      ClearTagsCommand(fileListNotifier: notifier, plan: plan).execute();

      expect(byPath('/a.mp3').tags, isEmpty);
      expect(byPath('/a.mp3').isModified, isTrue);
    });

    test('leaves unselected fields intact', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final plan = planClear(notifier.currentFiles, {'artist'});

      ClearTagsCommand(fileListNotifier: notifier, plan: plan).execute();

      expect(byPath('/a.mp3').tags, const {'title': 'T'});
    });

    test('a cleared field becomes an empty write, not an absent one', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final plan = planClear(notifier.currentFiles, null);

      ClearTagsCommand(fileListNotifier: notifier, plan: plan).execute();

      // This is what makes the removal actually reach disk: the writer
      // only ever sees keys, and turns an empty value into nullptr.
      expect(byPath('/a.mp3').modifiedTags, {'title': '', 'artist': ''});
    });

    test('only planned files are touched', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T'}),
        file('/b.mp3', const {'title': 'U'}),
      ]);
      final plan = planClear([byPath('/a.mp3')], null);

      ClearTagsCommand(fileListNotifier: notifier, plan: plan).execute();

      expect(byPath('/a.mp3').tags, isEmpty);
      expect(byPath('/b.mp3').tags, const {'title': 'U'});
      expect(byPath('/b.mp3').isModified, isFalse);
    });

    test('undo restores the exact previous tags', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final plan = planClear(notifier.currentFiles, null);
      final command = ClearTagsCommand(fileListNotifier: notifier, plan: plan);

      command.execute();
      command.undo();

      expect(byPath('/a.mp3').tags, const {'title': 'T', 'artist': 'A'});
    });

    test('undo clears the modified flag when it matches the original', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final plan = planClear(notifier.currentFiles, null);
      final command = ClearTagsCommand(fileListNotifier: notifier, plan: plan);

      command.execute();
      expect(byPath('/a.mp3').isModified, isTrue);

      command.undo();
      expect(byPath('/a.mp3').isModified, isFalse);
    });

    test('undo keeps the file modified when other edits remain', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final plan = planClear(notifier.currentFiles, null);
      final command = ClearTagsCommand(fileListNotifier: notifier, plan: plan);

      command.execute();
      // An unrelated edit made after the clear must survive the undo.
      notifier.updateFiles([
        byPath('/a.mp3').copyWith(tags: const {'year': '2026'}),
      ]);

      command.undo();
      expect(byPath('/a.mp3').isModified, isTrue);
      expect(byPath('/a.mp3').tags, const {
        'year': '2026',
        'title': 'T',
        'artist': 'A',
      });
    });

    test('undo does not resurrect fields cleared by a later command', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final first = planClear(notifier.currentFiles, null);
      final command = ClearTagsCommand(fileListNotifier: notifier, plan: first);

      command.execute();
      // Someone re-populates a field, then a second clear removes it again.
      notifier.updateFiles([
        byPath('/a.mp3').copyWith(tags: const {'title': 'NEW'}),
      ]);
      final second = planClear(notifier.currentFiles, null);
      ClearTagsCommand(fileListNotifier: notifier, plan: second).execute();
      expect(byPath('/a.mp3').tags, isEmpty);

      command.undo();
      expect(byPath('/a.mp3').tags, const {'title': 'T', 'artist': 'A'});
    });

    test('undo after a save keeps the file clean', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final plan = planClear(notifier.currentFiles, null);
      final command = ClearTagsCommand(fileListNotifier: notifier, plan: plan);

      command.execute();
      // Emulate a successful save, which re-baselines originalTags.
      notifier.updateFiles([
        byPath('/a.mp3').copyWith(
          isModified: false,
          originalTags: Map<String, String>.unmodifiable(byPath('/a.mp3').tags),
        ),
      ]);

      command.undo();
      expect(byPath('/a.mp3').isModified, isTrue);
      expect(byPath('/a.mp3').tags, const {'title': 'T', 'artist': 'A'});
    });

    test('executing twice is idempotent', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T', 'artist': 'A'}),
      ]);
      final plan = planClear(notifier.currentFiles, null);
      final command = ClearTagsCommand(fileListNotifier: notifier, plan: plan);

      command.execute();
      command.execute();

      expect(byPath('/a.mp3').tags, isEmpty);
    });

    test('an empty plan changes nothing', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T'}),
      ]);

      ClearTagsCommand(
        fileListNotifier: notifier,
        plan: ClearPlan.empty,
      ).execute();

      expect(byPath('/a.mp3').tags, const {'title': 'T'});
      expect(byPath('/a.mp3').isModified, isFalse);
    });

    test('carries the caller-supplied description for the undo label', () {
      notifier.addFiles([
        file('/a.mp3', const {'title': 'T'}),
      ]);
      final command = ClearTagsCommand(
        fileListNotifier: notifier,
        plan: planClear(notifier.currentFiles, null),
        description: 'Clear all tags (1 file(s))',
      );

      expect(command.description, 'Clear all tags (1 file(s))');
    });
  });
}
