import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/models/rename_pattern.dart';
import 'package:open_tag_editor/shared/services/rename_service.dart';

void main() {
  late RenameService service;

  setUp(() {
    service = RenameService();
  });

  group('RenameService.preview', () {
    test('generates filename from artist-title pattern', () {
      const file = AudioFile(
        path: '/music/song.mp3',
        filename: 'song.mp3',
        extension: '.mp3',
        fileSize: 5000000,
        tags: {'artist': 'The Beatles', 'title': 'Hey Jude'},
      );

      const pattern = RenamePattern(
        name: 'test',
        pattern: '%artist% - %title%',
      );

      expect(service.preview(file, pattern), 'The Beatles - Hey Jude.mp3');
    });

    test('pads track number to 2 digits', () {
      const file = AudioFile(
        path: '/music/song.flac',
        filename: 'song.flac',
        extension: '.flac',
        fileSize: 30000000,
        tags: {'title': 'Come Together', 'trackNumber': '1'},
      );

      const pattern = RenamePattern(name: 'test', pattern: '%track% - %title%');

      expect(service.preview(file, pattern), '01 - Come Together.flac');
    });

    test('handles missing tag values gracefully', () {
      const file = AudioFile(
        path: '/music/unknown.mp3',
        filename: 'unknown.mp3',
        extension: '.mp3',
        fileSize: 4000000,
        tags: {},
      );

      const pattern = RenamePattern(
        name: 'test',
        pattern: '%artist% - %title%',
      );

      // Should produce " - " which sanitizes to "_ - _" or similar
      final result = service.preview(file, pattern);
      expect(result, isNotEmpty);
    });
  });

  group('RenamePattern.apply', () {
    test('replaces all placeholders', () {
      const pattern = RenamePattern(
        name: 'full',
        pattern: '%artist% - %album%/%track% - %title%',
      );

      final tags = {
        'artist': 'Pink Floyd',
        'album': 'The Wall',
        'trackNumber': '3',
        'title': 'Another Brick in the Wall',
      };

      expect(
        pattern.apply(tags),
        'Pink Floyd - The Wall/03 - Another Brick in the Wall',
      );
    });
  });
}
