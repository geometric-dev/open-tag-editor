import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/services/tag_reader_service.dart';
import 'package:open_tag_editor/shared/services/taglib/atomic_write_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late AtomicWriteManager manager;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('atomic_write_test_');
    manager = AtomicWriteManager();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  String createOriginal({String content = 'ORIGINAL'}) {
    final path = p.join(tempDir.path, 'song.mp3');
    File(path).writeAsStringSync(content);
    return path;
  }

  group('AtomicWriteManager.writeAtomic', () {
    test('replaces the original with the written temp file', () async {
      final path = createOriginal();

      await manager.writeAtomic(path, (tempPath) async {
        // Temp file starts as a copy of the original.
        expect(File(tempPath).readAsStringSync(), 'ORIGINAL');
        expect(p.dirname(tempPath), tempDir.path);
        File(tempPath).writeAsStringSync('UPDATED');
      });

      expect(File(path).readAsStringSync(), 'UPDATED');
    });

    test('leaves no temp files behind on success', () async {
      final path = createOriginal();

      await manager.writeAtomic(path, (tempPath) async {
        File(tempPath).writeAsStringSync('X');
      });

      final leftovers = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path != path)
          .toList();
      expect(leftovers, isEmpty);
    });

    test('on write failure: deletes temp, keeps original intact', () async {
      final path = createOriginal();
      String? seenTempPath;

      await expectLater(
        manager.writeAtomic(path, (tempPath) async {
          seenTempPath = tempPath;
          throw Exception('disk exploded');
        }),
        throwsException,
      );

      expect(File(path).readAsStringSync(), 'ORIGINAL');
      expect(File(seenTempPath!).existsSync(), isFalse);
    });

    test('rename failure retains both files and reports paths', () async {
      final path = createOriginal();
      Directory? blocker;

      await expectLater(
        manager.writeAtomic(path, (tempPath) async {
          File(tempPath).writeAsStringSync('UPDATED');
          // Occupy the rename target with a directory so the atomic
          // replace must fail on every platform.
          File(path).deleteSync();
          blocker = Directory(path)..createSync();
        }),
        throwsA(
          isA<TagWriteException>().having(
            (e) => e.message,
            'message',
            contains('Temp file retained'),
          ),
        ),
      );

      // Temp retained for manual recovery, containing the written data.
      final temps = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path != path)
          .toList();
      expect(temps, hasLength(1));
      expect(temps.single.readAsStringSync(), 'UPDATED');

      blocker!.deleteSync();
    });

    test('throws when the original does not exist', () async {
      final missing = p.join(tempDir.path, 'nope.mp3');

      await expectLater(
        manager.writeAtomic(missing, (_) async {}),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
