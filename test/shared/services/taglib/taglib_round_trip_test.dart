@Timeout(Duration(minutes: 2))
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

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

/// These tests exercise the REAL native TagLib pipeline (reader + writer +
/// validation) and therefore only run where the repository's Windows DLL
/// can be loaded. They are skipped everywhere else rather than silently
/// passing, so a green run on a Windows dev machine is meaningful.
void main() {
  final dllFile = File(
    p.join(Directory.current.path, 'windows', 'taglib_c.dll'),
  );
  // The Windows DLLs are committed, so their presence proves nothing on a
  // POSIX host: attempting to load a PE image there throws. Gate on the
  // platform as well as the file.
  final dllAvailable = Platform.isWindows && dllFile.existsSync();

  late Directory tempDir;
  late TagLibReaderService reader;
  late TagLibWriterService writer;

  setUpAll(() {
    // Load tag.dll first so taglib_c.dll's dependency resolves even though
    // the test runner executable lives elsewhere (flutter cache).
    final tagDll = File(p.join(Directory.current.path, 'windows', 'tag.dll'));
    if (tagDll.existsSync()) {
      DynamicLibrary.open(tagDll.path);
    }
    final bindings = TagLibBindings(DynamicLibrary.open(dllFile.path));
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
    tempDir = Directory.systemTemp.createTempSync('taglib_roundtrip_');
  });

  tearDownAll(() {
    // setUpAll never runs when the platform gate skips every test, so
    // tempDir is legitimately uninitialised here.
    if (!dllAvailable) return;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String fixturePath(String suffix) => p.join(
    tempDir.path,
    'song_${DateTime.now().microsecondsSinceEpoch}.$suffix',
  );

  group('real TagLib pipeline', () {
    test(
      'MP3 write -> read round trip preserves all written fields',
      () async {
        final path = fixturePath('mp3');
        File(path).writeAsBytesSync(generateMinimalMp3());

        const title = 'Röund Trip — 日本語 🎵';
        await writer.writeTags(path, {
          'title': title,
          'artist': 'Artist & Sons',
          'album': 'Album',
          'genre': 'Test',
          'trackNumber': '7',
          'year': '2024',
        });

        final file = await reader.readTags(path);
        expect(file.tags['title'], title);
        expect(file.tags['artist'], 'Artist & Sons');
        expect(file.tags['album'], 'Album');
        expect(file.tags['genre'], 'Test');
        expect(file.tags['trackNumber'], '7');
        expect(file.tags['year'], '2024');
        expect(file.bitrate, greaterThan(0));
        expect(file.tagFormat, isNotNull);
      },
      skip: !dllAvailable ? 'taglib_c.dll not found' : null,
    );

    test(
      'FLAC vorbis comments survive a write cycle',
      () async {
        final path = fixturePath('flac');
        File(path).writeAsBytesSync(generateMinimalFlac());

        await writer.writeTags(path, {'title': 'Flac Round Trip'});

        final file = await reader.readTags(path);
        expect(file.tags['title'], 'Flac Round Trip');
        expect(file.tagFormat?.name, 'vorbisComment');
      },
      skip: !dllAvailable ? 'taglib_c.dll not found' : null,
    );

    test(
      'writing tags preserves unknown ID3v2 frames (ReplayGain TXXX)',
      () async {
        final path = fixturePath('mp3');
        File(path).writeAsBytesSync(generateMinimalMp3());
        _prependReplayGainFrame(path);

        // Sanity: marker present before the write.
        var bytes = File(path).readAsBytesSync();
        expect(_indexOfBytes(bytes, _rgMarker), greaterThan(-1));

        await writer.writeTags(path, {'title': 'After RG'});

        bytes = File(path).readAsBytesSync();
        expect(
          _indexOfBytes(bytes, _rgMarker),
          greaterThan(-1),
          reason:
              'A Properties-API write dropped the custom TXXX frame. '
              'Users would lose ReplayGain data on every save.',
        );

        final file = await reader.readTags(path);
        expect(file.tags['title'], 'After RG');
      },
      skip: !dllAvailable ? 'taglib_c.dll not found' : null,
    );
  });
}

/// ASCII bytes of the ReplayGain description we embed in the fixture.
final Uint8List _rgMarker = Uint8List.fromList(
  'REPLAYGAIN_TRACK_GAIN'.codeUnits,
);

/// Synchsafe integer encoding used by ID3v2 tag sizes.
Uint8List _synchsafe(int value) {
  return Uint8List.fromList([
    (value >> 21) & 0x7F,
    (value >> 14) & 0x7F,
    (value >> 7) & 0x7F,
    value & 0x7F,
  ]);
}

/// Finds [needle] inside [haystack], or -1.
int _indexOfBytes(Uint8List haystack, Uint8List needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

Uint8List _be32(int value) {
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

/// Prepends a hand-built ID3v2.3 tag containing one TXXX frame:
/// description "REPLAYGAIN_TRACK_GAIN", value "-7.89 dB".
void _prependReplayGainFrame(String mp3Path) {
  const desc = 'REPLAYGAIN_TRACK_GAIN';
  const value = '-7.89 dB';

  // Payload: encoding byte + desc \0 + value \0
  final payload = BytesBuilder()
    ..addByte(0x00) // ISO-8859-1
    ..add(desc.codeUnits)
    ..addByte(0x00)
    ..add(value.codeUnits)
    ..addByte(0x00);
  final payloadBytes = payload.toBytes();

  // Frame: "TXXX" + size (v2.3 plain big-endian) + flags + payload
  final frame = BytesBuilder()
    ..add('TXXX'.codeUnits)
    ..add(_be32(payloadBytes.length))
    ..addByte(0x00)
    ..addByte(0x00)
    ..add(payloadBytes);
  final frameBytes = frame.toBytes();

  // Tag header: "ID3" ver=2.3 flags=0 size=<synchsafe frames length>
  final tag = BytesBuilder()
    ..add([0x49, 0x44, 0x33])
    ..addByte(0x03)
    ..addByte(0x00)
    ..addByte(0x00)
    ..add(_synchsafe(frameBytes.length))
    ..add(frameBytes);
  final tagBytes = tag.toBytes();

  final original = File(mp3Path).readAsBytesSync();
  final out = BytesBuilder()
    ..add(tagBytes)
    ..add(original);
  File(mp3Path).writeAsBytesSync(out.toBytes());
}
