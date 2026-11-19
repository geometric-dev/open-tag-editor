import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/renamer/data/mask_evaluator.dart';
import 'package:open_tag_editor/features/renamer/data/mask_parser.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile _file(Map<String, String> tags) => AudioFile(
  path: r'C:\Music\file.mp3',
  filename: 'file.mp3',
  extension: '.mp3',
  fileSize: 1,
  tags: tags,
);

String _eval(String pattern, Map<String, String> tags) {
  final tokens = MaskParser().parse(pattern);
  return MaskEvaluator().evaluate(tokens, _file(tags));
}

void main() {
  group('MaskEvaluator delimiter collapsing', () {
    test('drops a leading delimiter before an empty variable', () {
      expect(_eval('%artist - %title', {'title': 'Song'}), 'Song');
    });

    test('drops a trailing delimiter after an empty variable', () {
      expect(_eval('%artist - %title', {'artist': 'Band'}), 'Band');
    });

    test('keeps a path separator before an empty disc when track follows', () {
      // The reported bug: %disc is empty, %track follows, and the backslash
      // between %album and %disc must survive so album and track do not merge.
      expect(
        _eval(r'%artist\%album\%disc%track', {
          'artist': 'Artist',
          'album': 'Album',
          'trackNumber': '1',
        }),
        r'Artist\Album\01',
      );
    });

    test('keeps the disc number when it is populated', () {
      expect(
        _eval(r'%artist\%album\%disc%track', {
          'artist': 'Artist',
          'album': 'Album',
          'discNumber': '1',
          'trackNumber': '1',
        }),
        r'Artist\Album\101',
      );
    });

    test('drops the separator when the empty variable is last', () {
      expect(
        _eval(r'%artist\%album\%disc', {'artist': 'Artist', 'album': 'Album'}),
        r'Artist\Album',
      );
    });
  });
}
