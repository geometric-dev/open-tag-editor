import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/models/grid_item.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/grid_items_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

void main() {
  group('buildGridItems', () {
    test('empty list returns empty', () {
      final result = buildGridItems(
        files: [],
        rootFolder: 'C:\\Music',
        isRecursive: true,
        isSorted: false,
      );

      expect(result, isEmpty);
    });

    test('recursive=false returns FileGridItems only, no separators', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\Rock\\song1.mp3',
          filename: 'song1.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Pop\\song2.mp3',
          filename: 'song2.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Jazz\\song3.mp3',
          filename: 'song3.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: 'C:\\Music',
        isRecursive: false,
        isSorted: false,
      );

      expect(result.length, equals(3));
      for (final item in result) {
        expect(item, isA<FileGridItem>());
      }
      expect(result.whereType<SeparatorGridItem>().length, equals(0));
      expect((result[0] as FileGridItem).fileIndex, equals(0));
      expect((result[1] as FileGridItem).fileIndex, equals(1));
      expect((result[2] as FileGridItem).fileIndex, equals(2));
    });

    test('isSorted=true returns FileGridItems only, no separators', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\Rock\\song1.mp3',
          filename: 'song1.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Pop\\song2.mp3',
          filename: 'song2.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Jazz\\song3.mp3',
          filename: 'song3.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: 'C:\\Music',
        isRecursive: true,
        isSorted: true,
      );

      expect(result.length, equals(3));
      for (final item in result) {
        expect(item, isA<FileGridItem>());
      }
      expect(result.whereType<SeparatorGridItem>().length, equals(0));
    });

    test('null rootFolder returns FileGridItems only', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\Rock\\song1.mp3',
          filename: 'song1.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Pop\\song2.mp3',
          filename: 'song2.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: null,
        isRecursive: true,
        isSorted: false,
      );

      expect(result.length, equals(2));
      for (final item in result) {
        expect(item, isA<FileGridItem>());
      }
      expect(result.whereType<SeparatorGridItem>().length, equals(0));
    });

    test('single file produces one separator + one file', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\Rock\\song.mp3',
          filename: 'song.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: 'C:\\Music',
        isRecursive: true,
        isSorted: false,
      );

      expect(result.length, equals(2));
      expect(result[0], isA<SeparatorGridItem>());
      expect((result[0] as SeparatorGridItem).relativePath, equals('Rock'));
      expect(result[1], isA<FileGridItem>());
      expect((result[1] as FileGridItem).file.filename, equals('song.mp3'));
    });

    test('all files in root folder', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\song1.mp3',
          filename: 'song1.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\song2.mp3',
          filename: 'song2.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\song3.mp3',
          filename: 'song3.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: 'C:\\Music',
        isRecursive: true,
        isSorted: false,
      );

      expect(result.length, equals(4));
      expect(result[0], isA<SeparatorGridItem>());
      expect((result[0] as SeparatorGridItem).relativePath, equals('Music'));
      expect(result[1], isA<FileGridItem>());
      expect(result[2], isA<FileGridItem>());
      expect(result[3], isA<FileGridItem>());
    });

    test('multi-folder ordering: root first, then alphabetical', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\song.mp3',
          filename: 'song.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Zebra\\song.mp3',
          filename: 'song.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Alpha\\song.mp3',
          filename: 'song.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: 'C:\\Music',
        isRecursive: true,
        isSorted: false,
      );

      final separators = result.whereType<SeparatorGridItem>().toList();
      expect(separators.length, equals(3));
      expect(separators[0].relativePath, equals('Music'));
      expect(separators[1].relativePath, equals('Alpha'));
      expect(separators[2].relativePath, equals('Zebra'));
    });

    test('files within group sorted by filename case-insensitive', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\Rock\\Charlie.mp3',
          filename: 'Charlie.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Rock\\alpha.mp3',
          filename: 'alpha.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Rock\\Beta.mp3',
          filename: 'Beta.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: 'C:\\Music',
        isRecursive: true,
        isSorted: false,
      );

      final fileItems = result.whereType<FileGridItem>().toList();
      expect(fileItems.length, equals(3));
      expect(fileItems[0].file.filename, equals('alpha.mp3'));
      expect(fileItems[1].file.filename, equals('Beta.mp3'));
      expect(fileItems[2].file.filename, equals('Charlie.mp3'));
    });

    test('fileIndex preserves original list position', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\Rock\\song1.mp3',
          filename: 'song1.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Pop\\song2.mp3',
          filename: 'song2.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Rock\\song3.mp3',
          filename: 'song3.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: 'C:\\Music',
        isRecursive: true,
        isSorted: false,
      );

      final fileItems = result.whereType<FileGridItem>().toList();
      // Files are regrouped by directory, but fileIndex should match
      // original position in the input list.
      for (final item in fileItems) {
        expect(item.file, equals(files[item.fileIndex]));
      }
    });

    test('intermediate directories without files get no separator', () {
      final files = [
        const AudioFile(
          path: 'C:\\Music\\Artist\\Album\\song1.mp3',
          filename: 'song1.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        const AudioFile(
          path: 'C:\\Music\\Artist\\Album\\song2.mp3',
          filename: 'song2.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
      ];

      final result = buildGridItems(
        files: files,
        rootFolder: 'C:\\Music',
        isRecursive: true,
        isSorted: false,
      );

      final separators = result.whereType<SeparatorGridItem>().toList();
      // Only one separator for 'Artist / Album', none for 'Artist' alone.
      expect(separators.length, equals(1));
      expect(separators[0].relativePath, equals('Artist / Album'));
    });
  });
}
