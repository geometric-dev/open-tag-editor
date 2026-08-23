import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/services/taglib/isolate_tag_reader_service.dart';

void main() {
  group('IsolateTagReaderService', () {
    test('empty batch returns empty without spawning work', () async {
      final service = IsolateTagReaderService();
      expect(await service.readTagsBatch(const []), isEmpty);
    });

    test(
      'batch round-trips through the isolate and captures per-file failures',
      () async {
        final service = IsolateTagReaderService();
        final missing = '${Directory.systemTemp.path}/'
            'ote_missing_${DateTime.now().microsecondsSinceEpoch}.mp3';

        final files = await service.readTagsBatch([missing]);

        expect(files, hasLength(1));
        expect(files.single.path, missing);
        // Whether the worker used TagLib or the pure-Dart fallback, a
        // nonexistent file must surface as readError, not throw.
        expect(files.single.readError, isNotNull);
      },
    );
  });
}
