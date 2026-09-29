import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/album_art/data/album_art_command.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

/// Distinct marker bytes so a test can tell two images apart.
AlbumArtData art(String marker) => AlbumArtData(
  bytes: Uint8List.fromList(marker.codeUnits),
  mimeType: 'image/png',
);

AudioFile file(String path, {AlbumArtData? albumArt, bool isModified = false}) {
  return AudioFile(
    path: path,
    filename: path.split('/').last,
    extension: '.mp3',
    fileSize: 1,
    albumArt: albumArt,
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

  void execute(AlbumArtCommand command) => command.execute();

  group('per-file art assignment', () {
    test('each file keeps its own image', () {
      notifier.addFiles([
        file('/a.mp3', albumArt: art('A')),
        file('/b.mp3', albumArt: art('B')),
      ]);

      // The shape a batch resize produces: one distinct result per file.
      execute(
        AlbumArtCommand(
          fileListNotifier: notifier,
          filePaths: const ['/a.mp3', '/b.mp3'],
          previousArtMap: {'/a.mp3': art('A'), '/b.mp3': art('B')},
          newArtByPath: {'/a.mp3': art('a'), '/b.mp3': art('b')},
          operationType: AlbumArtOperationType.add,
        ),
      );

      expect(byPath('/a.mp3').albumArt!.bytes, art('a').bytes);
      expect(
        byPath('/b.mp3').albumArt!.bytes,
        art('b').bytes,
        reason: "b must not be painted with a.mp3's resized image",
      );
    });

    test('a single newArt still applies one image to every file', () {
      notifier.addFiles([
        file('/a.mp3', albumArt: art('A')),
        file('/b.mp3', albumArt: art('B')),
      ]);

      execute(
        AlbumArtCommand(
          fileListNotifier: notifier,
          filePaths: const ['/a.mp3', '/b.mp3'],
          previousArtMap: {'/a.mp3': art('A'), '/b.mp3': art('B')},
          newArt: art('SHARED'),
          operationType: AlbumArtOperationType.add,
        ),
      );

      expect(byPath('/a.mp3').albumArt!.bytes, art('SHARED').bytes);
      expect(byPath('/b.mp3').albumArt!.bytes, art('SHARED').bytes);
    });

    test('a file with no per-file entry falls back to the shared art', () {
      notifier.addFiles([
        file('/a.mp3', albumArt: art('A')),
        file('/b.mp3', albumArt: art('B')),
      ]);

      execute(
        AlbumArtCommand(
          fileListNotifier: notifier,
          filePaths: const ['/a.mp3', '/b.mp3'],
          previousArtMap: {'/a.mp3': art('A'), '/b.mp3': art('B')},
          newArt: art('SHARED'),
          newArtByPath: {'/a.mp3': art('a')},
          operationType: AlbumArtOperationType.add,
        ),
      );

      expect(byPath('/a.mp3').albumArt!.bytes, art('a').bytes);
      expect(byPath('/b.mp3').albumArt!.bytes, art('SHARED').bytes);
    });

    test('files outside the command are untouched', () {
      notifier.addFiles([
        file('/a.mp3', albumArt: art('A')),
        file('/b.mp3', albumArt: art('B')),
      ]);

      execute(
        AlbumArtCommand(
          fileListNotifier: notifier,
          filePaths: const ['/a.mp3'],
          previousArtMap: {'/a.mp3': art('A')},
          newArt: art('NEW'),
          operationType: AlbumArtOperationType.add,
        ),
      );

      expect(byPath('/b.mp3').albumArt!.bytes, art('B').bytes);
    });
  });

  group('dirty state', () {
    test('writing art does not mark the file dirty', () {
      // Art is not a tag field, so modifiedTags cannot express it. A dirty
      // flag here would leave Save permanently enabled with nothing to write.
      notifier.addFiles([file('/a.mp3', albumArt: art('A'))]);

      execute(
        AlbumArtCommand(
          fileListNotifier: notifier,
          filePaths: const ['/a.mp3'],
          previousArtMap: {'/a.mp3': art('A')},
          newArtByPath: {'/a.mp3': art('a')},
          operationType: AlbumArtOperationType.add,
        ),
      );

      expect(byPath('/a.mp3').isModified, isFalse);
      expect(byPath('/a.mp3').modifiedTags, isEmpty);
    });

    test('a pre-existing dirty state survives an art write', () {
      notifier.addFiles([
        AudioFile(
          path: '/a.mp3',
          filename: 'a.mp3',
          extension: '.mp3',
          fileSize: 1,
          tags: const {'title': 'new'},
          originalTags: const {'title': 'old'},
          albumArt: art('A'),
          isModified: true,
        ),
      ]);

      execute(
        AlbumArtCommand(
          fileListNotifier: notifier,
          filePaths: const ['/a.mp3'],
          previousArtMap: {'/a.mp3': art('A')},
          newArtByPath: {'/a.mp3': art('a')},
          operationType: AlbumArtOperationType.add,
        ),
      );

      final updated = byPath('/a.mp3');
      expect(updated.isModified, isTrue);
      expect(updated.albumArt!.bytes, art('a').bytes);
    });
  });

  group('undo', () {
    test("restores each file's own previous art", () {
      notifier.addFiles([
        file('/a.mp3', albumArt: art('A')),
        file('/b.mp3', albumArt: art('B')),
      ]);

      final command = AlbumArtCommand(
        fileListNotifier: notifier,
        filePaths: const ['/a.mp3', '/b.mp3'],
        previousArtMap: {'/a.mp3': art('A'), '/b.mp3': art('B')},
        newArtByPath: {'/a.mp3': art('a'), '/b.mp3': art('b')},
        operationType: AlbumArtOperationType.add,
      );
      command
        ..execute()
        ..undo();

      expect(byPath('/a.mp3').albumArt!.bytes, art('A').bytes);
      expect(byPath('/b.mp3').albumArt!.bytes, art('B').bytes);
    });

    test('restores "no art" for a file that had none', () {
      notifier.addFiles([file('/a.mp3')]);

      final command = AlbumArtCommand(
        fileListNotifier: notifier,
        filePaths: const ['/a.mp3'],
        previousArtMap: const {},
        newArtByPath: {'/a.mp3': art('a')},
        operationType: AlbumArtOperationType.add,
      );
      command
        ..execute()
        ..undo();

      expect(byPath('/a.mp3').albumArt, isNull);
    });
  });

  group('description', () {
    test('names the operation and the file count', () {
      final single = AlbumArtCommand(
        fileListNotifier: notifier,
        filePaths: const ['/a.mp3'],
        previousArtMap: const {},
        newArt: art('a'),
        operationType: AlbumArtOperationType.add,
      );
      expect(single.description, 'Add album art');

      final batch = AlbumArtCommand(
        fileListNotifier: notifier,
        filePaths: const ['/a.mp3', '/b.mp3'],
        previousArtMap: const {},
        newArt: art('a'),
        operationType: AlbumArtOperationType.remove,
      );
      expect(batch.description, 'Remove album art (2 files)');
    });
  });
}
