import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/export_service.dart';

AudioFile file(Map<String, String> tags) {
  return AudioFile(
    path: r'C:\m\a.mp3',
    filename: 'a.mp3',
    extension: '.mp3',
    fileSize: 1,
    tags: tags,
    bitrate: 320,
    duration: 12.6,
  );
}

void main() {
  final columns = <ExportColumn>[
    (header: 'Filename', value: (f) => f.filename),
    (header: 'Title', value: (f) => f.tags['title'] ?? ''),
    (header: 'Artist', value: (f) => f.tags['artist'] ?? ''),
    (header: 'Bitrate', value: (f) => f.bitrate?.toString() ?? ''),
  ];

  test('CSV quotes fields containing commas, quotes, and newlines', () {
    final csv = ExportService.toCsv([
      file({'title': 'Hello, World', 'artist': 'The "Best" Band\nSecond line'}),
    ], columns);

    // BOM then header row.
    expect(csv, startsWith('\uFEFF'));
    expect(csv, contains('Filename,Title,Artist,Bitrate'));
    // RFC-4180: quoted fields may contain raw newlines, so assert on the
    // whole record rather than per-line.
    expect(csv, contains('"Hello, World"'));
    expect(csv, contains('"The ""Best"" Band\nSecond line"'));
  });

  test('CSV without BOM when requested', () {
    final csv = ExportService.toCsv([], columns, includeBom: false);
    expect(csv.startsWith('\uFEFF'), isFalse);
    expect(csv.split('\n').first, 'Filename,Title,Artist,Bitrate');
  });

  test('HTML escapes markup and renders header row', () {
    final html = ExportService.toHtml([
      file({'title': '<b>Bold</b> & "friends"'}),
    ], columns);

    expect(html, contains('&lt;b&gt;Bold&lt;/b&gt; &amp; &quot;friends&quot;'));
    expect(html, contains('<th>Title</th>'));
    expect(html, contains('<table>'));
  });

  test('serializeFor picks HTML by extension', () {
    final files = [
      file({'title': 'X'}),
    ];
    final out = ExportService.serializeFor('out.htm', files, columns);
    expect(out, startsWith('<!DOCTYPE html>'));

    final csvOut = ExportService.serializeFor('out.csv', files, columns);
    expect(csvOut, contains('Filename,Title,Artist,Bitrate'));
  });

  test('columnsFor maps visible ids and skips non-exportable ones', () {
    final cols = ExportService.columnsFor({
      'tagIndicator',
      'filename',
      'title',
      'isrc',
      'duration',
      'nonexistentColumn',
    });
    final headers = cols.map((c) => c.header).toList();
    expect(headers, contains('Filename'));
    expect(headers, contains('ISRC'));
    // tagIndicator has no export mapping and must be dropped.
    expect(cols.any((c) => c.header == 'tagIndicator'), isFalse);
    expect(cols.any((c) => c.header == 'nonexistentColumn'), isFalse);
  });

  test('duration column exports whole seconds', () {
    final cols = ExportService.columnsFor({'duration'});
    expect(cols.single.value(file({})), '13');
  });
}
