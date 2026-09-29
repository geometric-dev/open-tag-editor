@Timeout(Duration(minutes: 2))
library;

import 'dart:ffi';
import 'dart:io';

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

/// Real-library coverage for ReplayGain (PRD 19).
///
/// The TXXX spelling ReplayGain uses on ID3v2 is the same key TagLib reports
/// for a Vorbis Comment, so these assertions are about the *mapper* the app
/// controls, not about TagLib: if the app does not request the property, the
/// values are simply absent from [TagLibReaderService.readTags], and a
/// clear has no key to write. These tests therefore pin both directions
/// against actual files on disk.
void main() {
  final dllFile = File(
    p.join(Directory.current.path, 'windows', 'taglib_c.dll'),
  );
  final dllAvailable = Platform.isWindows && dllFile.existsSync();

  late Directory tempDir;
  late TagLibReaderService reader;
  late TagLibWriterService writer;

  setUpAll(() {
    if (!dllAvailable) return;
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
    tempDir = Directory.systemTemp.createTempSync('replaygain_');
  });

  tearDownAll(() {
    if (!dllAvailable) return;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String fixturePath(String suffix) => p.join(
    tempDir.path,
    'rg_${DateTime.now().microsecondsSinceEpoch}.$suffix',
  );

  group('ReplayGain round trip', () {
    test('written ReplayGain values are read back', () async {
      final path = fixturePath('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {
        'title': 'With RG',
        'replayGainTrackGain': '-6.50 dB',
        'replayGainTrackPeak': '0.988000',
        'replayGainAlbumGain': '-8.20 dB',
        'replayGainAlbumPeak': '1.000000',
      });

      final tags = (await reader.readTags(path)).tags;
      expect(tags['replayGainTrackGain'], '-6.50 dB');
      expect(tags['replayGainTrackPeak'], '0.988000');
      expect(tags['replayGainAlbumGain'], '-8.20 dB');
      expect(tags['replayGainAlbumPeak'], '1.000000');
    }, skip: !dllAvailable ? 'requires the native Windows TagLib DLL' : null);

    test('ReplayGain survives a write of unrelated fields', () async {
      final path = fixturePath('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {
        'title': 'Before',
        'replayGainTrackGain': '-6.50 dB',
      });
      await writer.writeTags(path, {'title': 'After'});

      final tags = (await reader.readTags(path)).tags;
      expect(
        tags['replayGainTrackGain'],
        '-6.50 dB',
        reason: 'An unrelated edit must not drop loudness data.',
      );
      expect(tags['title'], 'After');
    }, skip: !dllAvailable ? 'requires the native Windows TagLib DLL' : null);

    test('an empty value clears ReplayGain on disk', () async {
      final path = fixturePath('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());

      await writer.writeTags(path, {
        'title': 'T',
        'replayGainTrackGain': '-6.50 dB',
        'replayGainAlbumGain': '-8.20 dB',
      });
      // This is exactly what ClearTagsCommand sends: the field disappears
      // from the in-memory map, so modifiedTags reports it as ''.
      await writer.writeTags(path, {
        'title': 'T',
        'replayGainTrackGain': '',
        'replayGainAlbumGain': '',
      });

      final tags = (await reader.readTags(path)).tags;
      expect(tags.containsKey('replayGainTrackGain'), isFalse);
      expect(tags.containsKey('replayGainAlbumGain'), isFalse);
      expect(tags['title'], 'T', reason: 'other fields must be untouched');
    }, skip: !dllAvailable ? 'requires the native Windows TagLib DLL' : null);

    test('ReplayGain works on Vorbis Comment formats too', () async {
      final path = fixturePath('flac');
      File(path).writeAsBytesSync(generateMinimalFlac());

      await writer.writeTags(path, {
        'title': 'FLAC RG',
        'replayGainTrackGain': '-4.20 dB',
      });

      final tags = (await reader.readTags(path)).tags;
      expect(tags['replayGainTrackGain'], '-4.20 dB');
    }, skip: !dllAvailable ? 'requires the native Windows TagLib DLL' : null);

    test('a file with no ReplayGain reports none', () async {
      final path = fixturePath('mp3');
      File(path).writeAsBytesSync(generateMinimalMp3());
      await writer.writeTags(path, {'title': 'No RG'});

      final tags = (await reader.readTags(path)).tags;
      expect(tags.containsKey('replayGainTrackGain'), isFalse);
      expect(tags.containsKey('replayGainAlbumGain'), isFalse);
    }, skip: !dllAvailable ? 'requires the native Windows TagLib DLL' : null);
  });
}
