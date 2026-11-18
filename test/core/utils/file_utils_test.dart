import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/utils/cancellation_token.dart';
import 'package:open_tag_editor/core/utils/file_utils.dart';

void main() {
  group('FileUtils.isAudioFile', () {
    test('recognizes supported formats', () {
      expect(FileUtils.isAudioFile('song.mp3'), isTrue);
      expect(FileUtils.isAudioFile('track.FLAC'), isTrue);
      expect(FileUtils.isAudioFile('audio.ogg'), isTrue);
      expect(FileUtils.isAudioFile('music.m4a'), isTrue);
      expect(FileUtils.isAudioFile('file.wav'), isTrue);
      expect(FileUtils.isAudioFile('song.opus'), isTrue);
    });

    test('rejects unsupported formats', () {
      expect(FileUtils.isAudioFile('document.pdf'), isFalse);
      expect(FileUtils.isAudioFile('image.png'), isFalse);
      expect(FileUtils.isAudioFile('video.mkv'), isFalse);
      expect(FileUtils.isAudioFile('readme.txt'), isFalse);
    });
  });

  group('FileUtils.sanitizeFilename', () {
    test('removes invalid characters', () {
      expect(FileUtils.sanitizeFilename('song<>:"/\\|?*'), 'song_________');
    });

    test('trims whitespace', () {
      expect(FileUtils.sanitizeFilename('  song  '), 'song');
    });

    test('handles empty result', () {
      expect(FileUtils.sanitizeFilename(''), 'unnamed');
    });

    test('preserves valid filenames', () {
      expect(
        FileUtils.sanitizeFilename('Artist - Title (feat. Other)'),
        'Artist - Title (feat. Other)',
      );
    });
  });

  group('FileUtils.getExtension', () {
    test('returns lowercase extension with dot', () {
      expect(FileUtils.getExtension('song.MP3'), '.mp3');
      expect(FileUtils.getExtension('/path/to/file.Flac'), '.flac');
    });
  });

  group('FileUtils read-only checks', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('file_utils_ro_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('normal file is not read-only', () {
      final file = File('${tempDir.path}/normal.txt');
      file.writeAsStringSync('hello');

      expect(FileUtils.isFileReadOnly(file), isFalse);
    });

    test('non-existent file is not read-only', () {
      final file = File('${tempDir.path}/does_not_exist.txt');
      expect(FileUtils.isFileReadOnly(file), isFalse);
    });

    test('file open for reading is not falsely reported as read-only', () {
      final file = File('${tempDir.path}/open_file.txt');
      file.writeAsStringSync('testing file locks');

      // Open a read handle to simulate Soulseek or a media player
      final raf = file.openSync(mode: FileMode.read);
      try {
        expect(FileUtils.isFileReadOnly(file), isFalse);
      } finally {
        raf.closeSync();
      }
    });

    test('detects and clears read-only flag', () {
      final file = File('${tempDir.path}/readonly.txt');
      file.writeAsStringSync('readonly content');

      if (Platform.isWindows) {
        Process.runSync('attrib', ['+r', file.path]);
      } else {
        Process.runSync('chmod', ['444', file.path]);
      }

      expect(FileUtils.isFileReadOnly(file), isTrue);

      final cleared = FileUtils.clearReadOnly(file);
      expect(cleared, isTrue);
      expect(FileUtils.isFileReadOnly(file), isFalse);
    });
  });

  group('FileUtils.listAudioFiles with progress and cancellation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('file_utils_list_test_');
      for (var i = 0; i < 5; i++) {
        File('${tempDir.path}/track$i.mp3').writeAsStringSync('mp3 data');
      }
      File('${tempDir.path}/ignore.txt').writeAsStringSync('text');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('reports progressive discovery count', () async {
      final counts = <int>[];
      final files = await FileUtils.listAudioFiles(
        tempDir.path,
        recursive: false,
        onProgress: (c) => counts.add(c),
      );

      expect(files.length, 5);
      expect(counts, isNotEmpty);
      expect(counts.last, 5);
    });

    test('aborts early when cancellation token is cancelled', () async {
      final token = CancellationToken();
      final files = await FileUtils.listAudioFiles(
        tempDir.path,
        recursive: false,
        cancellationToken: token,
        onProgress: (c) {
          if (c >= 2) {
            token.cancel();
          }
        },
      );

      expect(token.isCancelled, isTrue);
      expect(files.length, lessThan(5));
    });
  });
}
