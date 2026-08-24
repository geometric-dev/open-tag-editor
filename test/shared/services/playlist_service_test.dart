import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/playlist_service.dart';

void main() {
  test('extended m3u contains EXTINF and paths', () {
    final files = [
      AudioFile(
        path: '/music/a.mp3',
        filename: 'a.mp3',
        extension: '.mp3',
        fileSize: 100,
        tags: {'artist': 'A', 'title': 'T'},
        duration: 123.4,
      ),
      AudioFile(
        path: '/music/b.flac',
        filename: 'b.flac',
        extension: '.flac',
        fileSize: 100,
        tags: {'title': 'B2'},
        duration: null,
      ),
    ];
    final m3u = PlaylistService.generateM3U(files, useAbsolutePaths: true);
    expect(m3u, contains('#EXTM3U'));
    expect(m3u, contains('#EXTINF:123,A - T'));
    expect(m3u, contains('#EXTINF:-1,B2'));
    expect(m3u, contains('/music/a.mp3'));
  });

  test('relative paths when baseDirectory given', () {
    final files = [
      AudioFile(
        path: r'C:\music\album\a.mp3',
        filename: 'a.mp3',
        extension: '.mp3',
        fileSize: 100,
      ),
    ];
    final m3u = PlaylistService.generateM3U(
      files,
      baseDirectory: r'C:\music\album',
    );
    expect(m3u, contains('a.mp3'));
    expect(m3u, isNot(contains(r'C:\music\album\a.mp3')));
  });
}
