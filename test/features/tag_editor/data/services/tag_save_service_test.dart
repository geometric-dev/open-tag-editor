import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/services/tag_save_service.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/tag_reader_service.dart';

/// Fake writer that records calls and returns canned batch results.
class FakeTagWriterService implements TagWriterService {
  FakeTagWriterService(this.resultsByPath);

  final Map<String, bool> resultsByPath;
  final List<Map<String, Map<String, String>>> batchCalls = [];

  @override
  Future<void> writeTags(String path, Map<String, String> tags) async {}

  @override
  Future<void> writeAlbumArt(String path, AlbumArtData art) async {}

  @override
  Future<void> removeAlbumArt(String path) async {}

  @override
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  ) async {
    batchCalls.add(Map.of(fileTagsMap));
    return [
      for (final entry in fileTagsMap.entries)
        TagWriteResult(
          path: entry.key,
          success: resultsByPath[entry.key] ?? true,
        ),
    ];
  }
}

AudioFile fileWithTags(
  String path, {
  required Map<String, String> tags,
  Map<String, String>? originalTags,
  bool isModified = false,
}) {
  return AudioFile(
    path: path,
    filename: path.split('/').last,
    extension: '.mp3',
    fileSize: 1,
    tags: tags,
    originalTags:
        originalTags != null ? Map.unmodifiable(originalTags) : null,
    isModified: isModified,
  );
}

void main() {
  group('TagSaveService.saveAllModified', () {
    test('returns null when no files are modified', () async {
      final notifier = FileListNotifier();
      notifier.addFiles([
        fileWithTags('/a.mp3', tags: {'title': 'A'}),
      ]);
      final writer = FakeTagWriterService({});
      final service =
          TagSaveService(writer: writer, fileListNotifier: notifier);

      expect(await service.saveAllModified(), isNull);
      expect(writer.batchCalls, isEmpty);
    });

    test('returns null when modified files have no actual field changes',
        () async {
      final original = {'title': 'Same'};
      final notifier = FileListNotifier();
      notifier.addFiles([
        // isModified flag set but tags identical to originals.
        fileWithTags(
          '/a.mp3',
          tags: {'title': 'Same'},
          originalTags: original,
          isModified: true,
        ),
      ]);
      final writer = FakeTagWriterService({});
      final service =
          TagSaveService(writer: writer, fileListNotifier: notifier);

      expect(await service.saveAllModified(), isNull);
      expect(writer.batchCalls, isEmpty);
    });

    test('writes only changed fields and marks successful files clean',
        () async {
      final notifier = FileListNotifier();
      notifier.addFiles([
        fileWithTags(
          '/a.mp3',
          tags: {'title': 'New Title', 'artist': 'Kept'},
          originalTags: {'title': 'Old', 'artist': 'Kept'},
          isModified: true,
        ),
      ]);
      final writer = FakeTagWriterService({'/a.mp3': true});
      final service =
          TagSaveService(writer: writer, fileListNotifier: notifier);

      final summary = await service.saveAllModified();

      expect(summary, isNotNull);
      expect(summary!.allSuccess, isTrue);
      expect(summary.successCount, 1);
      // Only the changed field is written.
      expect(writer.batchCalls.single['/a.mp3'], {'title': 'New Title'});
      // File is marked clean with refreshed originals.
      final saved = notifier.currentFiles.single;
      expect(saved.isModified, isFalse);
      expect(saved.originalTags!['title'], 'New Title');
    });

    test('leaves failed files dirty and reports failure counts', () async {
      final notifier = FileListNotifier();
      notifier.addFiles([
        fileWithTags(
          '/good.mp3',
          tags: {'title': 'Good New'},
          originalTags: {'title': 'Good Old'},
          isModified: true,
        ),
        fileWithTags(
          '/bad.mp3',
          tags: {'title': 'Bad New'},
          originalTags: {'title': 'Bad Old'},
          isModified: true,
        ),
      ]);
      final writer = FakeTagWriterService({'/good.mp3': true, '/bad.mp3':
          false});
      final service =
          TagSaveService(writer: writer, fileListNotifier: notifier);

      final summary = await service.saveAllModified();

      expect(summary!.allSuccess, isFalse);
      expect(summary.successCount, 1);
      expect(summary.failureCount, 1);
      expect(summary.attemptedTags.keys, containsAll(['/good.mp3',
          '/bad.mp3']));

      final good = notifier.currentFiles
          .singleWhere((f) => f.path == '/good.mp3');
      final bad =
          notifier.currentFiles.singleWhere((f) => f.path == '/bad.mp3');
      expect(good.isModified, isFalse);
      expect(bad.isModified, isTrue);
    });
  });
}
