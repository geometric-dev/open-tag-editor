import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/gnudb_service.dart';
import 'package:open_tag_editor/features/online_lookup/data/lookup_service_exception.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile track(String name, {double? duration, String? trackNumber}) {
  return AudioFile(
    path: '/m/$name',
    filename: name,
    extension: '.mp3',
    fileSize: 1,
    duration: duration,
    tags: {'trackNumber': ?trackNumber},
  );
}

void main() {
  group('GnuDbService.buildToc', () {
    test('single track starts at frame 150 with lead-out', () {
      // 10 seconds = 750 frames; lead-out = 150 + 750 + 150 (2s gap).
      final toc = GnuDbService.buildToc([10.0]);
      expect(toc, '1+1+150+900');
    });

    test('multiple tracks accumulate offsets', () {
      // Offsets: track1@150; track2@150+4s*75=450; track3@+5s*75=825;
      // lead-out adds 6s*75 -> 1275.
      final toc = GnuDbService.buildToc([4.0, 5.0, 6.0]);
      expect(toc, equals('1+3+150+450+825+1275'));
    });

    test('throws on empty durations', () {
      expect(() => GnuDbService.buildToc([]), throwsArgumentError);
    });
  });

  group('GnuDbService.orderForToc', () {
    test('uses track number when all files have one', () {
      final ordered = GnuDbService.orderForToc([
        track('b.mp3', trackNumber: '2'),
        track('a.mp3', trackNumber: '1'),
      ]);
      expect(ordered.map((f) => f.filename).toList(), ['a.mp3', 'b.mp3']);
    });

    test('falls back to filename when any track number is missing', () {
      final ordered = GnuDbService.orderForToc([
        track('02 - Beta.mp3', trackNumber: '2'),
        track('01 - Alpha.mp3'), // no number
        track('03 - Gamma.mp3', trackNumber: 'x'),
      ]);
      expect(ordered.map((f) => f.filename).toList(), [
        '01 - Alpha.mp3',
        '02 - Beta.mp3',
        '03 - Gamma.mp3',
      ]);
    });
  });

  group('parseCdLookupResponse', () {
    test('parses entries and builds composite ids with embedded tracks', () {
      const body = '''
[
  {"discid":"abc123","genre":"Rock","artist":"The Band","title":"Great Album",
   "year":1999,"tracks":["One","Two","Three"]},
  {"discid":"def456","genre":"Pop","artist":"Other","title":"Ok",
   "year":"2001","tracks":[{"title":"X"},{"title":"Y"}]},
  {"artist":"Broken","title":"No discid"}
]
''';
      final result = GnuDbService.parseCdLookupResponse(body);

      expect(result.results, hasLength(2));
      expect(result.results.first.id, 'gnudb:Rock:abc123');
      expect(result.results.first.source.name, 'gnudb');
      expect(result.results.first.year, '1999');

      final tracks = result.tracksByDiscId['gnudb:Rock:abc123']!;
      expect(tracks.map((t) => t.title), ['One', 'Two', 'Three']);
      expect(tracks.first.position, 1);

      final second = result.tracksByDiscId['gnudb:Pop:def456']!;
      expect(second.map((t) => t.title), ['X', 'Y']);

      // Entry without discid is skipped entirely.
      expect(result.results.any((r) => r.title == 'No discid'), isFalse);
    });

    test('malformed JSON throws LookupServiceException', () {
      expect(
        () => GnuDbService.parseCdLookupResponse('{not json'),
        throwsA(isA<LookupServiceException>()),
      );
    });

    test('non-list JSON throws', () {
      expect(
        () => GnuDbService.parseCdLookupResponse('{"oops":true}'),
        throwsA(isA<LookupServiceException>()),
      );
    });
  });
}
