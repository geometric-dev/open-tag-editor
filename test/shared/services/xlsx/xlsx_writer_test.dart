import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/export_service.dart';
import 'package:open_tag_editor/shared/services/xlsx/xlsx_writer.dart';

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

/// Locates a little-endian u32 inside [data], or -1.
int _findBytes(List<int> data, List<int> needle, [int start = 0]) {
  outer:
  for (var i = start; i <= data.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (data[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

void main() {
  test('ZipWriter produces valid local header and correct CRC', () {
    final zip = ZipWriter()
      ..addText('hello.txt', 'hi'); // crc32("hi") known value

    final bytes = zip.build();
    expect(bytes.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]); // PK\x03\x04

    // CRC at offset 14 (after sig+version+flags+method+time+date) must
    // match the algorithm's output for the payload.
    const crcOffset = 14;
    final expectedCrc = crc32(Uint8List.fromList('hi'.codeUnits));
    final actualCrc =
        bytes[crcOffset] |
        (bytes[crcOffset + 1] << 8) |
        (bytes[crcOffset + 2] << 16) |
        (bytes[crcOffset + 3] << 24);
    expect(actualCrc, expectedCrc);

    // EOCD signature present at the end region.
    expect(_findBytes(bytes, [0x50, 0x4B, 0x05, 0x06]), greaterThan(-1));
  });

  test('crc32 matches known vectors', () {
    expect(crc32(Uint8List(0)), 0);
    expect(crc32(Uint8List.fromList('123456789'.codeUnits)), 0xCBF43926);
  });

  test('toXlsx emits workbook with headers, rows and numeric cells', () {
    final columns = <ExportColumn>[
      (header: 'Filename', value: (f) => f.filename),
      (header: 'Track #', value: (f) => f.tags['trackNumber'] ?? ''),
      (header: 'Title', value: (f) => f.tags['title'] ?? ''),
    ];
    final bytes = ExportService.toXlsx([
      file({'trackNumber': '007', 'title': '<Special> & "Chars"'}),
    ], columns);

    // ZIP magic at the start.
    expect(bytes.sublist(0, 2), [0x50, 0x4B]);

    final asString = String.fromCharCodes(bytes);
    expect(asString, contains('xl/workbook.xml'));
    expect(asString, contains('[Content_Types].xml'));
    expect(asString, contains('sheet1.xml'));

    // Sheet XML is stored uncompressed, so it appears verbatim.
    expect(asString, contains('<row r="1">'));
    expect(asString, contains('Filename'));
    expect(asString, contains('&lt;Special&gt; &amp; &quot;Chars&quot;'));

    // "Track #" column value "007" must be inlineStr (leading zero kept).
    expect(asString, contains('t="inlineStr"'));
    expect(asString, contains('>007<'));
  });

  test('serializeFor dispatches .xlsx to binary output', () {
    final out = ExportService.serializeFor(
      'out.xlsx',
      [
        file({'title': 'X'}),
      ],
      [(header: 'Title', value: (f) => f.tags['title'] ?? '')],
    );
    expect(out, isA<Uint8List>());
    expect((out as Uint8List).sublist(0, 2), [0x50, 0x4B]);
  });
}
