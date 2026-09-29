import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tools/data/strip_id3v1_command.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/id3v1_codec.dart';

import '../../../helpers/audio_fixtures.dart';

AudioFile file(String path, {String extension = '.mp3'}) {
  return AudioFile(
    path: path,
    filename: path.split(Platform.pathSeparator).last,
    extension: extension,
    fileSize: 1,
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('strip_id3v1_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String createMp3({bool withV1 = false, String? name}) {
    final path =
        '${tempDir.path}${Platform.pathSeparator}${name ?? 't${DateTime.now().microsecondsSinceEpoch}.mp3'}';
    File(path).writeAsBytesSync(generateMinimalMp3());
    if (withV1) {
      Id3v1Codec.writeToFile(path, {
        'title': 'Stale',
        'artist': 'Old',
        'trackNumber': '7',
      });
    }
    return path;
  }

  group('stripId3v1From', () {
    test('removes the block from an MP3 that has one', () {
      final path = createMp3(withV1: true);
      final sizeWithTag = File(path).lengthSync();

      final result = StripId3v1Command.stripId3v1From([file(path)]);

      expect(result.stripped, [path]);
      expect(result.skipped, isEmpty);
      expect(result.hasErrors, isFalse);
      expect(File(path).lengthSync(), sizeWithTag - 128);
      expect(Id3v1Codec.readFromFile(path), isNull);
    });

    test('reports an MP3 without a block as skipped, not stripped', () {
      final path = createMp3();

      final result = StripId3v1Command.stripId3v1From([file(path)]);

      expect(result.stripped, isEmpty);
      expect(result.skipped, [path]);
    });

    test('non-MP3 files are skipped without touching disk', () {
      final path = createMp3(withV1: true, name: 'track.flac');
      final sizeBefore = File(path).lengthSync();

      final result = StripId3v1Command.stripId3v1From([
        file(path, extension: '.flac'),
      ]);

      expect(result.skipped, [path]);
      expect(File(path).lengthSync(), sizeBefore);
    });

    test('a missing file is recorded as an error, not a crash', () {
      final missing = '${tempDir.path}${Platform.pathSeparator}gone.mp3';

      final result = StripId3v1Command.stripId3v1From([file(missing)]);

      expect(result.hasErrors, isTrue);
      expect(result.errors.containsKey(missing), isTrue);
      expect(result.stripped, isEmpty);
    });

    test('mixed selection separates stripped, skipped and errors', () {
      final tagged = createMp3(withV1: true, name: 'tagged.mp3');
      final untagged = createMp3(name: 'untagged.mp3');
      final flac = createMp3(withV1: true, name: 'x.flac');
      final missing = '${tempDir.path}${Platform.pathSeparator}gone.mp3';

      final result = StripId3v1Command.stripId3v1From([
        file(tagged),
        file(untagged),
        file(flac, extension: '.flac'),
        file(missing),
      ]);

      expect(result.stripped, [tagged]);
      expect(result.skipped, containsAll([untagged, flac]));
      expect(result.errors.keys, [missing]);
    });

    test('the .mp3 extension match is case-insensitive', () {
      final path = createMp3(withV1: true, name: 'upper.MP3');

      final result = StripId3v1Command.stripId3v1From([
        file(path, extension: '.MP3'),
      ]);

      expect(result.stripped, [path]);
    });
  });

  group('planFor', () {
    test('returns null when nothing in the selection has a block', () {
      final path = createMp3();

      expect(StripId3v1Command.planFor([file(path)]), isNull);
    });

    test('returns null for an empty selection', () {
      expect(StripId3v1Command.planFor(const []), isNull);
    });

    test('captures the current values so undo can restore them', () {
      final path = createMp3(withV1: true);

      final command = StripId3v1Command.planFor([file(path)])!;

      expect(command.files.map((f) => f.path), [path]);
      expect(command.previousTags[path]!['title'], 'Stale');
      expect(command.previousTags[path]!['artist'], 'Old');
      expect(command.previousTags[path]!['trackNumber'], '7');
    });

    test('excludes files that have no block from the plan', () {
      final tagged = createMp3(withV1: true, name: 'a.mp3');
      final untagged = createMp3(name: 'b.mp3');

      final command = StripId3v1Command.planFor([
        file(tagged),
        file(untagged),
      ])!;

      expect(command.files.map((f) => f.path), [tagged]);
      expect(command.previousTags.containsKey(untagged), isFalse);
      expect(command.description, contains('1 file(s)'));
    });
  });

  group('undo', () {
    test('re-materialises the block with its original values', () {
      final path = createMp3(withV1: true);
      final command = StripId3v1Command.planFor([file(path)])!;

      command.execute();
      expect(Id3v1Codec.readFromFile(path), isNull);

      command.undo();
      final restored = Id3v1Codec.readFromFile(path);
      expect(restored, isNotNull);
      expect(restored!['title'], 'Stale');
      expect(restored['artist'], 'Old');
      expect(restored['trackNumber'], '7');
    });

    test('a full strip then undo round-trips to the original length', () {
      final path = createMp3(withV1: true);
      final sizeWithTag = File(path).lengthSync();
      final command = StripId3v1Command.planFor([file(path)])!;

      command.execute();
      expect(File(path).lengthSync(), sizeWithTag - 128);

      command.undo();
      expect(File(path).lengthSync(), sizeWithTag);
    });

    test('undo does nothing for a file that no longer exists', () {
      final path = createMp3(withV1: true);
      final command = StripId3v1Command.planFor([file(path)])!;
      command.execute();

      File(path).deleteSync();
      // Must not throw: a file removed between strip and undo cannot be
      // restored, and there is nothing useful to report from here.
      expect(command.undo, returnsNormally);
    });
  });
}
