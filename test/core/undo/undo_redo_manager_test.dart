import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/undo/undo_redo_manager.dart';
import 'package:open_tag_editor/features/tag_editor/data/commands/tag_edit_command.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

/// A command that reports whether it changed anything.
class _CountingCommand implements UndoableCommand {
  _CountingCommand({required this.changes});

  final int changes;
  int undoCount = 0;

  @override
  String get description => 'counting';

  @override
  bool execute() => changes > 0;

  @override
  void undo() => undoCount++;
}

void main() {
  group('UndoRedoManager', () {
    test('records a command that changed something', () {
      final manager = UndoRedoManager();
      final recorded = manager.execute(_CountingCommand(changes: 1));

      expect(recorded, isTrue);
      expect(manager.state.canUndo, isTrue);
      expect(manager.state.undoStack, hasLength(1));
    });

    test('does not record a command that changed nothing', () {
      final manager = UndoRedoManager();
      final recorded = manager.execute(_CountingCommand(changes: 0));

      expect(recorded, isFalse);
      expect(
        manager.state.canUndo,
        isFalse,
        reason: 'a no-op must not occupy a slot on the undo stack',
      );
      expect(manager.state.undoStack, isEmpty);
    });

    test('a no-op does not consume the user’s next undo', () {
      // The regression this prevents: press Enter in a field without editing
      // it, then Ctrl+Z -- the undo was consumed by an entry that did nothing,
      // so the user's real previous state was one step further away than they
      // expected.
      final manager = UndoRedoManager();
      manager.execute(_CountingCommand(changes: 1));
      manager.execute(_CountingCommand(changes: 0));

      manager.undo();

      expect(manager.state.undoStack, isEmpty);
      expect(manager.state.redoStack, hasLength(1));
    });

    test('a no-op does not clear the redo stack', () {
      final manager = UndoRedoManager();
      manager.execute(_CountingCommand(changes: 1));
      manager.undo();
      expect(manager.state.canRedo, isTrue);

      manager.execute(_CountingCommand(changes: 0));

      expect(
        manager.state.canRedo,
        isTrue,
        reason: 'redo history should survive an accidental no-op edit',
      );
    });

    test('the history is still capped at 100 entries', () {
      final manager = UndoRedoManager();
      for (var i = 0; i < 120; i++) {
        manager.execute(_CountingCommand(changes: 1));
      }

      expect(manager.state.undoStack, hasLength(100));
    });
  });

  group('TagEditCommand reports no-ops', () {
    late FileListNotifier notifier;

    setUp(() {
      notifier = FileListNotifier();
      notifier.addFiles([
        const AudioFile(
          path: '/a.mp3',
          filename: 'a.mp3',
          extension: '.mp3',
          fileSize: 1,
          tags: {'title': 'Existing'},
          originalTags: {'title': 'Existing'},
        ),
      ]);
    });

    test('setting the same value is a no-op', () {
      final changed = TagEditCommand(
        fileListNotifier: notifier,
        filePaths: const ['/a.mp3'],
        fieldName: 'title',
        newValue: 'Existing',
        previousValues: const {'/a.mp3': 'Existing'},
      ).execute();

      expect(changed, isFalse);
      expect(notifier.currentFiles.first.tags['title'], 'Existing');
      expect(notifier.currentFiles.first.isModified, isFalse);
    });

    test('setting a different value is a change', () {
      final changed = TagEditCommand(
        fileListNotifier: notifier,
        filePaths: const ['/a.mp3'],
        fieldName: 'title',
        newValue: 'New',
        previousValues: const {'/a.mp3': 'Existing'},
      ).execute();

      expect(changed, isTrue);
      expect(notifier.currentFiles.first.tags['title'], 'New');
    });

    test('targeting a path that is not loaded is a no-op', () {
      final changed = TagEditCommand(
        fileListNotifier: notifier,
        filePaths: const ['/missing.mp3'],
        fieldName: 'title',
        newValue: 'New',
        previousValues: const {},
      ).execute();

      expect(changed, isFalse);
    });

    test('clearing a populated field is a change, not a no-op', () {
      // Guards the fix in 6e7469d: the panel's copy now says clearing a field
      // removes it from every file, and the command must report that as a
      // real change so it reaches the undo stack.
      final changed = TagEditCommand(
        fileListNotifier: notifier,
        filePaths: const ['/a.mp3'],
        fieldName: 'title',
        newValue: '',
        previousValues: const {'/a.mp3': 'Existing'},
      ).execute();

      expect(changed, isTrue);
      expect(notifier.currentFiles.first.modifiedTags, {'title': ''});
    });
  });
}
