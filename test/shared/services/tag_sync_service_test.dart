import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/id3v1_codec.dart';
import 'package:open_tag_editor/shared/services/tag_sync_service.dart';
import 'package:open_tag_editor/shared/services/tag_reader_service.dart';

/// Writer stub that records writeTags calls without touching disk.
class RecordingWriter implements TagWriterService {
  final calls = <MapEntry<String, Map<String, String>>>[];

  @override
  Future<void> writeTags(String path, Map<String, String> tags) async {
    calls.add(MapEntry(path, Map.of(tags)));
  }

  @override
  Future<void> writeAlbumArt(String path, AlbumArtData art) async {}

  @override
  Future<void> removeAlbumArt(String path) async {}

  @override
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  ) async =>
      const [];
}

AudioFile mp3(String path, Map<String, String> tags) => AudioFile(
      path: path,
      filename: path.split('/').last,
      extension: '.mp3',
      fileSize: 1,
      tags: tags,
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tag_sync_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String createMp3({bool withV1 = false}) {
    final path =
        '${tempDir.path}/t_${DateTime.now().microsecondsSinceEpoch}.mp3';
    // Minimal MPEG frame content (not parsed by the codec).
    File(path).writeAsBytesSync(List.filled(417, 0x55, growable: false));
    if (withV1) {
      Id3v1Codec.writeToFile(path, {'title': 'Stale', 'artist': 'Old'});
    }
    return path;
  }

  group('Id3v1Codec round trip', () {
    test('build then parse preserves fields incl. v1.1 track', () {
      final block = Id3v1Codec.build({
        'title': 'Song',
        'artist': 'Artist',
        'album': 'Album',
        'year': '1999',
        'comment': 'Hello',
        'trackNumber': '7',
      });

      expect(block.length, 128);
      expect(String.fromCharCodes(block.sublist(0, 3)), 'TAG');

      final tags = Id3v1Codec.parse(block)!;
      expect(tags['title'], 'Song');
      expect(tags['artist'], 'Artist');
      expect(tags['album'], 'Album');
      expect(tags['year'], '1999');
      expect(tags['comment'], 'Hello');
      expect(tags['trackNumber'], '7');
      expect(block[127], 0xFF);
    });

    test('v1.0 when no track: comment may use full 30 bytes', () {
      final longComment = 'x' * 30;
      final tags = Id3v1Codec.parse(
        Id3v1Codec.build({'comment': longComment}),
      )!;
      expect(tags['comment'], longComment);
      expect(tags.containsKey('trackNumber'), isFalse);
    });

    test('long values truncate; unicode maps to ?', () {
      final tags = Id3v1Codec.parse(Id3v1Codec.build({
        'title': 'T' * 40,
        'artist': '日本語',
      }))!;
      expect(tags['title'], 'T' * 30);
      // Each unmappable CJK char becomes a single '?' byte.
      expect((tags['artist'] ?? '').split('').every((c) => c == '?'), isTrue);
    });

    test('parse rejects non-TAG tail', () {
      final junk = Uint8List.fromList(List.filled(128, 0x41));
      expect(Id3v1Codec.parse(junk), isNull);
    });
  });

  group('file operations', () {
    test('writeToFile appends then replaces in place', () {
      final path = createMp3();
      final sizeBefore = File(path).lengthSync();

      final appended = Id3v1Codec.writeToFile(
        path,
        {'title': 'First'},
      );
      expect(appended, isFalse);
      expect(File(path).lengthSync(), sizeBefore + 128);

      final replaced = Id3v1Codec.writeToFile(path, {'title': 'Second'});
      expect(replaced, isTrue);
      expect(File(path).lengthSync(), sizeBefore + 128);
      expect(Id3v1Codec.readFromFile(path)!['title'], 'Second');
    });

    test('stripFromFile removes an existing tag once', () {
      final path = createMp3();
      Id3v1Codec.writeToFile(path, {'title': 'X'});
      final withTag = File(path).lengthSync();

      expect(Id3v1Codec.stripFromFile(path), isTrue);
      expect(File(path).lengthSync(), withTag - 128);
      expect(Id3v1Codec.stripFromFile(path), isFalse);
    });
  });

  group('TagSyncService', () {
    test('syncToId3v1 writes visible tags into ID3v1 for mp3s only', () async {
      final mp3Path = createMp3();
      final service = TagSyncService(tagWriter: RecordingWriter());

      final result = await service.syncToId3v1([
        mp3(mp3Path, {'title': 'Live Tags', 'artist': 'Band'}),
        mp3('${tempDir.path}/x.flac', {'title': 'Nope'}),
      ]);

      expect(result.updatedCount, 1);
      expect(result.skippedCount, 1);

      final v1 = Id3v1Codec.readFromFile(mp3Path)!;
      expect(v1['title'], 'Live Tags');
      expect(v1['artist'], 'Band');
    });

    test('syncFromId3v1 fills only empty v2 fields via writer delta', () async {
      final writer = RecordingWriter();
      final service = TagSyncService(tagWriter: writer);
      final path = createMp3(withV1: true);
      // v1 contains title=Stale, artist=Old.

      await service.syncFromId3v1([
        // artist empty -> filled from v1; title present -> untouched.
        mp3(path, {'title': 'Current Title'}),
      ]);

      expect(writer.calls, hasLength(1));
      expect(writer.calls.single.key, path);
      expect(writer.calls.single.value, {'artist': 'Old'});
    });

    test('syncFromId3v1 skips files whose v1 adds nothing', () async {
      final writer = RecordingWriter();
      final service = TagSyncService(tagWriter: writer);
      final path = createMp3(withV1: true);

      final result = await service.syncFromId3v1([
        // Both v1 fields already present in v2 -> nothing to fill.
        mp3(path, {'title': 'Stale', 'artist': 'Old', 'album': 'A'}),
      ]);

      expect(result.updatedCount, 0);
      expect(result.skippedCount, 1);
      expect(writer.calls, isEmpty);
    });

    test('failures are captured per file, batch continues', () async {
      final service = TagSyncService(tagWriter: RecordingWriter());
      final missing = '${tempDir.path}/ghost.mp3';

      final result = await service.syncToId3v1([
        mp3(missing, {'title': 'X'}),
      ]);

      expect(result.allSuccess, isFalse);
      expect(result.failures.single.path, missing);
    });
  });
}
