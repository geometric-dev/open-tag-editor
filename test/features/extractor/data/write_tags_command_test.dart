import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/extractor/data/models/write_mode.dart';
import 'package:open_tag_editor/features/extractor/data/write_tags_command.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile file({
  required String path,
  required Map<String, String> tags,
  bool modified = false,
}) {
  return AudioFile(
    path: path,
    filename: p_basename(path),
    extension: '.mp3',
    fileSize: 1,
    tags: tags,
    originalTags: Map.unmodifiable(tags),
    isModified: modified,
  );
}

/// Basename helper avoiding a package:path dependency in this test.
String p_basename(String path) {
  final i = path.lastIndexOf('/');
  return i == -1 ? path : path.substring(i + 1);
}

void main() {
  late FileListNotifier notifier;

  setUp(() {
    notifier = FileListNotifier();
  });

  group('WriteTagsCommand', () {
    test('overwrite mode replaces existing values and adds new ones', () async {
      notifier.addFiles([
        file(path: '/m/01.mp3', tags: {'title': 'Old', 'artist': 'Keep'}),
      ]);
      final previous = Map.of(notifier.currentFiles.single.tags);

      WriteTagsCommand(
        fileListNotifier: notifier,
        filePaths: ['/m/01.mp3'],
        extractedValues: {
          '/m/01.mp3': {'title': 'New', 'album': 'Extracted'},
        },
        previousValues: {'/m/01.mp3': previous},
        writeMode: WriteMode.overwriteExisting,
      ).execute();

      final tags = notifier.currentFiles.single.tags;
      expect(tags['title'], 'New');
      expect(tags['album'], 'Extracted');
      expect(tags['artist'], 'Keep');
      expect(notifier.currentFiles.single.isModified, isTrue);
    });

    test('fillEmptyOnly never clobbers existing values', () async {
      notifier.addFiles([
        file(path: '/m/01.mp3', tags: {'title': 'Existing'}),
      ]);

      WriteTagsCommand(
        fileListNotifier: notifier,
        filePaths: ['/m/01.mp3'],
        extractedValues: {
          '/m/01.mp3': {'title': 'Would Clobber', 'artist': 'Filled'},
        },
        previousValues: {
          '/m/01.mp3': const {'title': 'Existing'},
        },
        writeMode: WriteMode.fillEmptyOnly,
      ).execute();

      final tags = notifier.currentFiles.single.tags;
      expect(tags['title'], 'Existing', reason: 'existing value preserved');
      expect(tags['artist'], 'Filled', reason: 'empty field filled');
    });

    test('undo restores the exact previous tag map and dirty state', () async {
      notifier.addFiles([
        file(
          path: '/m/01.mp3',
          tags: {'title': 'Original'},
          modified: false,
        ),
      ]);

      final command = WriteTagsCommand(
        fileListNotifier: notifier,
        filePaths: ['/m/01.mp3'],
        extractedValues: {
          '/m/01.mp3': {'title': 'Changed', 'album': 'Added'},
        },
        previousValues: {
          '/m/01.mp3': {'title': 'Original'},
        },
        writeMode: WriteMode.overwriteExisting,
      );

      command.execute();
      expect(notifier.currentFiles.single.isModified, isTrue);

      command.undo();

      final restored = notifier.currentFiles.single;
      expect(restored.tags, {'title': 'Original'});
      // Undo recomputes dirty state against originalTags: identical -> clean.
      expect(restored.isModified, isFalse);
    });

    test('files outside filePaths are untouched', () async {
      notifier.addFiles([
        file(path: '/m/a.mp3', tags: {'title': 'A'}),
        file(path: '/m/b.mp3', tags: {'title': 'B'}),
      ]);

      WriteTagsCommand(
        fileListNotifier: notifier,
        filePaths: ['/m/a.mp3'],
        extractedValues: {
          '/m/a.mp3': {'title': 'X'},
        },
        previousValues: {
          '/m/a.mp3': const {'title': 'A'},
        },
        writeMode: WriteMode.overwriteExisting,
      ).execute();

      expect(
          notifier.currentFiles
              .firstWhere((f) => f.path == '/m/b.mp3')
              .tags['title'],
          'B');
    });
  });
}
