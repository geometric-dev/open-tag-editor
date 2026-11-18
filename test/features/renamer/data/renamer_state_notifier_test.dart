import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/undo/undo_redo_manager.dart';
import 'package:open_tag_editor/features/renamer/data/renamer_state_notifier.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:path/path.dart' as p;

void main() {
  group('RenamerStateNotifier', () {
    late Directory tempDir;
    late UndoRedoManager undoRedo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('renamer_notifier_test_');
      undoRedo = UndoRedoManager();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    AudioFile makeFile(String name, {Map<String, String> tags = const {}}) {
      final file = File(p.join(tempDir.path, name));
      file.writeAsStringSync('DATA');
      return AudioFile(
        path: file.path,
        filename: name,
        extension: '.mp3',
        fileSize: 4,
        tags: tags,
      );
    }

    test('executeRename skips files in skipPaths', () async {
      final f1 = makeFile('01 Song.mp3', tags: {'title': 'Track One'});
      final f2 = makeFile('02 Song.mp3', tags: {'title': 'Track Two'});

      final notifier = RenamerStateNotifier(
        files: [f1, f2],
        undoRedoManager: undoRedo,
      );

      notifier.setPattern('%title');

      // Skip f1
      final result = await notifier.executeRename(skipPaths: {f1.path});

      expect(result.renamedCount, 1);
      expect(result.skippedCount, 1);
      expect(result.errorCount, 0);

      expect(File(f1.path).existsSync(), isTrue, reason: 'f1 was skipped');
      expect(
        File(p.join(tempDir.path, 'Track Two.mp3')).existsSync(),
        isTrue,
        reason: 'f2 was renamed',
      );
    });

    test('executeRename skips all files when all are in skipPaths', () async {
      final f1 = makeFile('01 Song.mp3', tags: {'title': 'Track One'});

      final notifier = RenamerStateNotifier(
        files: [f1],
        undoRedoManager: undoRedo,
      );

      notifier.setPattern('%title');

      final result = await notifier.executeRename(skipPaths: {f1.path});

      expect(result.renamedCount, 0);
      expect(result.skippedCount, 1);
      expect(result.errorCount, 0);
      expect(File(f1.path).existsSync(), isTrue);
    });
  });
}
