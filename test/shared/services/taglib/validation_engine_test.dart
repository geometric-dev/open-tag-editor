import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/tag_reader_service.dart';
import 'package:open_tag_editor/shared/services/taglib/validation_engine.dart';

/// Reader stub returning a canned [AudioFile].
class StubReader implements TagReaderService {
  StubReader(this.file);

  final AudioFile file;

  @override
  Future<AudioFile> readTags(String path) async => file;

  @override
  Future<List<AudioFile>> readTagsBatch(List<String> paths) async => [file];
}

AudioFile fileWithTags(Map<String, String> tags) {
  return AudioFile(
    path: '/x/a.mp3',
    filename: 'a.mp3',
    extension: '.mp3',
    fileSize: 1,
    tags: tags,
  );
}

void main() {
  late ValidationEngine engine;

  setUp(() {
    // Engine reads back whatever this canned file contains.
    engine = ValidationEngine(
      StubReader(
        fileWithTags({'title': 'Song', 'artist': 'Artist', 'trackNumber': '3'}),
      ),
    );
  });

  group('ValidationEngine.validate', () {
    test('passes when every expected field matches', () async {
      await engine.validate('/x/a.mp3', {'title': 'Song', 'artist': 'Artist'});
    });

    test('throws listing the mismatched field on value difference', () async {
      await expectLater(
        engine.validate('/x/a.mp3', {'title': 'Wrong'}),
        throwsA(
          isA<TagWriteException>().having(
            (e) => e.message,
            'message',
            allOf(contains('title'), contains('Song')),
          ),
        ),
      );
    });

    test(
      'empty expectation passes when field absent, fails when present',
      () async {
        // 'genre' is absent from the read-back -> clearing it succeeded.
        await engine.validate('/x/a.mp3', {'genre': ''});

        // 'title' is still present with a value -> clearing failed.
        await expectLater(
          engine.validate('/x/a.mp3', {'title': ''}),
          throwsA(isA<TagWriteException>()),
        );
      },
    );

    test(
      'missing actual value counts as mismatch against a real expectation',
      () async {
        await expectLater(
          engine.validate('/x/a.mp3', {'composer': 'Someone'}),
          throwsA(
            isA<TagWriteException>().having(
              (e) => e.message,
              'message',
              contains("got ''"),
            ),
          ),
        );
      },
    );

    test(
      'track number with total compares against the number portion only',
      () async {
        // Writer merged "3/12"; reader split it back to '3'.
        await engine.validate('/x/a.mp3', {'trackNumber': '3/12'});
      },
    );
  });
}
