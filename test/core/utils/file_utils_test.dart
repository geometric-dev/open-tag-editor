import 'package:flutter_test/flutter_test.dart';
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
}
