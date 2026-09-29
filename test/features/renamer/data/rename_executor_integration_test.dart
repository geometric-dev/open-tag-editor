import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/renamer/data/models/conflict_strategy.dart';
import 'package:open_tag_editor/features/renamer/data/models/rename_plan.dart';
import 'package:open_tag_editor/features/renamer/data/rename_executor.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late RenameExecutor executor;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('rename_executor_test_');
    executor = RenameExecutor();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  String createFile(String relativePath, {String content = 'DATA'}) {
    final file = File(p.join(tempDir.path, relativePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return file.path;
  }

  RenamePlan plan(String sourceRel, String targetRel) {
    final sourcePath = p.join(tempDir.path, sourceRel);
    return RenamePlan(
      sourcePath: sourcePath,
      targetPath: p.join(tempDir.path, targetRel),
      audioFile: AudioFile(
        path: sourcePath,
        filename: p.basename(sourcePath),
        extension: '.mp3',
        fileSize: 4,
      ),
    );
  }

  group('RenameExecutor.execute', () {
    test('renames files and reports counts', () async {
      final a = createFile('01 Song.mp3');
      createFile('02 Other.mp3');

      final result = await executor.execute([
        plan('01 Song.mp3', '01 Renamed.mp3'),
        plan('02 Other.mp3', 'sub/02 Moved.mp3'),
      ], strategy: ConflictStrategy.skip);

      expect(result.renamedCount, 2);
      expect(result.errorCount, 0);
      expect(File(a).existsSync(), isFalse, reason: 'source should be gone');
      expect(File(p.join(tempDir.path, '01 Renamed.mp3')).existsSync(), isTrue);
      // Nested mask folders are created on demand.
      expect(
        File(p.join(tempDir.path, 'sub', '02 Moved.mp3')).readAsStringSync(),
        'DATA',
      );
    });

    test(
      'skip strategy leaves conflicting target and source untouched',
      () async {
        createFile('a.mp3');
        createFile('b.mp3');
        createFile('existing.mp3', content: 'KEEP ME');

        final result = await executor.execute([
          plan('b.mp3', 'existing.mp3'),
        ], strategy: ConflictStrategy.skip);

        expect(result.skippedCount, 1);
        expect(
          File(p.join(tempDir.path, 'existing.mp3')).readAsStringSync(),
          'KEEP ME',
        );
        expect(File(p.join(tempDir.path, 'b.mp3')).existsSync(), isTrue);
      },
    );

    test('overwrite strategy replaces the target with the source', () async {
      createFile('src.mp3', content: 'NEW');
      createFile('dst.mp3', content: 'OLD');

      final result = await executor.execute([
        plan('src.mp3', 'dst.mp3'),
      ], strategy: ConflictStrategy.overwrite);

      expect(result.renamedCount, 1);
      expect(File(p.join(tempDir.path, 'dst.mp3')).readAsStringSync(), 'NEW');
      expect(File(p.join(tempDir.path, 'src.mp3')).existsSync(), isFalse);
    });

    test('autoIncrement strategy picks the next free suffix', () async {
      createFile('src.mp3');
      createFile('dst.mp3', content: 'FIRST');

      final result = await executor.execute([
        plan('src.mp3', 'dst.mp3'),
      ], strategy: ConflictStrategy.autoIncrement);

      expect(result.renamedCount, 1);
      expect(
        File(p.join(tempDir.path, 'dst (1).mp3')).readAsStringSync(),
        'DATA',
      );
      // The pre-existing target keeps its content.
      expect(File(p.join(tempDir.path, 'dst.mp3')).readAsStringSync(), 'FIRST');
    });

    test('renames .cdg karaoke companion when present', () async {
      final audio = createFile('track01.mp3');
      final cdg = createFile('track01.cdg', content: 'CDGDATA');

      final result = await executor.execute([
        plan('track01.mp3', '01 - Song.mp3'),
      ], strategy: ConflictStrategy.skip);

      expect(result.renamedCount, 1);
      expect(File(audio).existsSync(), isFalse);
      expect(File(cdg).existsSync(), isFalse);
      expect(
        File(p.join(tempDir.path, '01 - Song.cdg')).readAsStringSync(),
        'CDGDATA',
      );
    });

    test('absent .cdg companion is simply ignored', () async {
      createFile('plain.mp3');

      final result = await executor.execute([
        plan('plain.mp3', 'renamed.mp3'),
      ], strategy: ConflictStrategy.skip);

      expect(result.renamedCount, 1);
      expect(result.errorCount, 0);
    });

    test('missing source produces a per-file error, batch continues', () async {
      final ok = createFile('ok.mp3');

      final result = await executor.execute([
        plan('ghost.mp3', 'whatever.mp3'),
        plan('ok.mp3', 'ok renamed.mp3'),
      ], strategy: ConflictStrategy.overwrite);

      expect(result.renamedCount, 1);
      expect(result.errorCount, 1);
      expect(result.errors.single.filePath, endsWith('ghost.mp3'));
      expect(
        File(ok).existsSync(),
        isFalse,
        reason: 'second plan still executed',
      );
      expect(File(p.join(tempDir.path, 'ok renamed.mp3')).existsSync(), isTrue);
    });
  });

  group('RenameExecutor.dryRun', () {
    test(
      'flags missing sources and invalid targets without touching disk',
      () async {
        final results = await executor.dryRun([
          plan('not there.mp3', 'fine.mp3'),
          plan('x.mp3', 'bad|name.mp3'), // '|' invalid on Windows
        ]);

        expect(results[0].isValid, isFalse);
        expect(
          results[0].errors.any((e) => e.contains('does not exist')),
          isTrue,
        );
        if (Platform.isWindows) {
          expect(
            results[1].isValid,
            isFalse,
            reason: 'invalid character rejected on Windows',
          );
        }
        // Nothing was created or moved.
        expect(tempDir.listSync().whereType<File>(), isEmpty);
      },
    );
  });
}
