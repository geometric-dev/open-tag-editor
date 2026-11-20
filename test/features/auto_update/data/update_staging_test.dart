import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/auto_update/data/update_staging.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UpdateStaging pending marker', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('update_staging_test_');
      UpdateStaging.overrideBaseDir = tempDir.path;
    });

    tearDown(() {
      UpdateStaging.overrideBaseDir = null;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('readPending returns null when nothing is staged', () {
      expect(UpdateStaging.readPending(), isNull);
    });

    test('write + read round-trips a swap update', () {
      final payload = Directory(p.join(tempDir.path, 'payload'))
        ..createSync(recursive: true);
      UpdateStaging.writePending(
        PendingUpdate(
          version: '0.7.0',
          kind: PendingUpdateKind.swap,
          sourcePath: payload.path,
        ),
      );

      final pending = UpdateStaging.readPending();
      expect(pending, isNotNull);
      expect(pending!.version, '0.7.0');
      expect(pending.kind, PendingUpdateKind.swap);
      expect(pending.sourcePath, payload.path);
    });

    test('write + read round-trips an installer update', () {
      final installer = File(p.join(tempDir.path, 'setup.exe'))
        ..writeAsStringSync('x');
      UpdateStaging.writePending(
        PendingUpdate(
          version: '0.7.0',
          kind: PendingUpdateKind.installer,
          sourcePath: installer.path,
        ),
      );

      final pending = UpdateStaging.readPending();
      expect(pending?.kind, PendingUpdateKind.installer);
    });

    test('readPending returns null if the source has vanished', () {
      UpdateStaging.writePending(
        PendingUpdate(
          version: '0.7.0',
          kind: PendingUpdateKind.swap,
          sourcePath: p.join(tempDir.path, 'gone'),
        ),
      );
      expect(UpdateStaging.readPending(), isNull);
    });

    test('readPending returns null on a corrupt marker', () {
      final dir = Directory(UpdateStaging.baseDir())
        ..createSync(recursive: true);
      File(p.join(dir.path, 'pending.json')).writeAsStringSync('not json');
      expect(UpdateStaging.readPending(), isNull);
    });

    test('clearPending removes the marker', () {
      final payload = Directory(p.join(tempDir.path, 'payload'))
        ..createSync(recursive: true);
      UpdateStaging.writePending(
        PendingUpdate(
          version: '0.7.0',
          kind: PendingUpdateKind.swap,
          sourcePath: payload.path,
        ),
      );
      UpdateStaging.clearPending();
      expect(UpdateStaging.readPending(), isNull);
    });
  });
}
