@Timeout(Duration(minutes: 2))
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/settings/data/models/id3v2_version.dart';
import 'package:open_tag_editor/features/settings/data/models/tag_encoding.dart';
import 'package:open_tag_editor/features/settings/data/models/tag_write_options.dart';
import 'package:open_tag_editor/shared/services/taglib/backup_manager.dart';
import 'package:open_tag_editor/shared/services/taglib/taglib_bindings.g.dart';
import 'package:open_tag_editor/shared/services/taglib/taglib_reader_service.dart';
import 'package:open_tag_editor/shared/services/taglib/taglib_writer_service.dart';
import 'package:open_tag_editor/shared/services/taglib/validation_engine.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/audio_fixtures.dart';

/// Reads the raw (unsplit) property list for [key], so a test can tell the
/// difference between one property holding "A; B" and two properties holding
/// "A" and "B". The reader joins multi-values for display, which is exactly
/// the distinction these tests need to make.
List<String> rawValues(TagLibBindings bindings, String path, String key) {
  final handle = bindings.taglib_file_new(path.toNativeUtf8());
  final keyNative = key.toNativeUtf8();
  try {
    final valuesPtr = bindings.taglib_property_get(handle, keyNative);
    if (valuesPtr == nullptr) return const [];
    try {
      final out = <String>[];
      for (var i = 0; valuesPtr[i] != nullptr; i++) {
        out.add(valuesPtr[i].cast<Utf8>().toDartString());
      }
      return out;
    } finally {
      bindings.taglib_property_free(valuesPtr);
    }
  } finally {
    malloc.free(keyNative);
    bindings.taglib_file_free(handle);
  }
}

void main() {
  final dllFile = File(
    p.join(Directory.current.path, 'windows', 'taglib_c.dll'),
  );
  final dllAvailable = Platform.isWindows && dllFile.existsSync();

  late Directory tempDir;
  late TagLibReaderService reader;
  late TagLibWriterService writer;
  late TagLibBindings bindings;

  setUpAll(() {
    if (!dllAvailable) return;
    final tagDll = File(p.join(Directory.current.path, 'windows', 'tag.dll'));
    if (tagDll.existsSync()) {
      DynamicLibrary.open(tagDll.path);
    }
    bindings = TagLibBindings(DynamicLibrary.open(dllFile.path));
    reader = TagLibReaderService(bindings);
    writer = TagLibWriterService(
      bindings,
      BackupManager(isBackupEnabled: () => false),
      ValidationEngine(reader),
      getWriteOptions: () => const TagWriteOptions(
        id3v2Version: Id3v2Version.v24,
        encoding: TagEncoding.utf8,
      ),
    );
    tempDir = Directory.systemTemp.createTempSync('multivalue_');
  });

  tearDownAll(() {
    if (!dllAvailable) return;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String fixture(String suffix) => p.join(
    tempDir.path,
    'mv_${DateTime.now().microsecondsSinceEpoch}.$suffix',
  );

  final skip = dllAvailable ? null : 'requires the native Windows TagLib DLL';

  group('multi-value writing', () {
    test('two artists become two properties, not one joined string', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {'artist': 'First Artist; Second Artist'});

      final raw = rawValues(bindings, path, 'ARTIST');
      expect(
        raw,
        containsAll(['First Artist', 'Second Artist']),
        reason: 'values must be separate properties, not a joined literal',
      );
      expect(raw.length, 2);
    }, skip: skip);

    test('the reader rejoins them for display', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {'artist': 'First Artist; Second Artist'});

      final tags = (await reader.readTags(path)).tags;
      expect(tags['artist'], contains('First Artist'));
      expect(tags['artist'], contains('Second Artist'));
    }, skip: skip);

    test('a single value is not turned into a list', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {'artist': 'Solo Artist'});

      expect(rawValues(bindings, path, 'ARTIST'), ['Solo Artist']);
    }, skip: skip);

    test('replacing a multi-value replaces rather than appends', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {'artist': 'A; B'});
      await writer.writeTags(path, {'artist': 'C; D; E'});

      final raw = rawValues(bindings, path, 'ARTIST');
      expect(raw, containsAll(['C', 'D', 'E']));
      expect(
        raw.where((v) => v == 'A' || v == 'B'),
        isEmpty,
        reason: 'the previous values must not survive the replacement',
      );
    }, skip: skip);

    test('multiple genres survive a round trip', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {'genre': 'Rock; Alternative; Live'});

      final raw = rawValues(bindings, path, 'GENRE');
      expect(raw, containsAll(['Rock', 'Alternative', 'Live']));
    }, skip: skip);

    test('non-multi-value fields are never split', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      // A comment that genuinely contains a semicolon must stay one value.
      await writer.writeTags(path, {
        'title': 'AC/DC; Live',
        'comment': 'First half; second half',
      });

      expect(rawValues(bindings, path, 'TITLE'), ['AC/DC; Live']);
      expect(rawValues(bindings, path, 'COMMENT'), ['First half; second half']);
    }, skip: skip);

    test('clearing a multi-value field removes every value', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {'artist': 'A; B'});
      await writer.writeTags(path, {'artist': ''});

      expect(rawValues(bindings, path, 'ARTIST'), isEmpty);
    }, skip: skip);

    test('multi-value works on Vorbis Comment formats', () async {
      final path = fixture('flac');
      File(path).writeAsBytesSync(generateMinimalFlac());

      await writer.writeTags(path, {'albumArtist': 'Artist X; Artist Y'});

      final raw = rawValues(bindings, path, 'ALBUMARTIST');
      expect(raw, containsAll(['Artist X', 'Artist Y']));
    }, skip: skip);

    test('an empty segment is dropped rather than written as blank', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {'artist': 'A; ; B'});

      final raw = rawValues(bindings, path, 'ARTIST');
      expect(raw, isNot(contains('')));
      expect(raw, containsAll(['A', 'B']));
    }, skip: skip);

    test('an unrelated write does not disturb multi-values', () async {
      final path = fixture('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {'artist': 'A; B'});
      await writer.writeTags(path, {'title': 'New Title'});

      final raw = rawValues(bindings, path, 'ARTIST');
      expect(raw, containsAll(['A', 'B']));
    }, skip: skip);
  });
}
