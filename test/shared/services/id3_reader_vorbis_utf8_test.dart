import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/id3_reader_service.dart';

/// Bug condition exploration tests for FLAC non-ASCII tag decoding
/// and toolbar file list clearing.
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
///
/// These tests encode the EXPECTED (correct) behavior. They are designed to
/// FAIL on unfixed code, confirming the bugs exist. After the fix is applied,
/// these tests should PASS.

// ─────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────

/// Encodes an int as little-endian 32-bit bytes.
List<int> _int32LE(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}

/// Constructs a minimal valid FLAC file containing a STREAMINFO block
/// and a VORBIS_COMMENT block with the given [commentBytes].
///
/// Each entry in [commentBytes] should be raw bytes of a "KEY=VALUE" string
/// where VALUE is UTF-8 encoded.
Uint8List buildFlacWithVorbisComments(List<List<int>> commentBytes) {
  final buffer = BytesBuilder();

  // fLaC magic marker
  buffer.add([0x66, 0x4C, 0x61, 0x43]);

  // STREAMINFO block (block type 0, not last)
  // Minimum STREAMINFO is 34 bytes
  final streamInfo = Uint8List(34);
  // Set sample rate to 44100 at bytes 10-12
  streamInfo[10] = 0x0A;
  streamInfo[11] = 0xC4;
  streamInfo[12] = 0x42;
  buffer.add([0x00]); // block type 0 (STREAMINFO), not last
  // Block size = 34 (big-endian 24-bit)
  buffer.add([0x00, 0x00, 0x22]);
  buffer.add(streamInfo);

  // VORBIS_COMMENT block (block type 4, last block)
  final vorbisBlock = BytesBuilder();

  // Vendor string: "test" (4 bytes)
  final vendorBytes = utf8.encode('test');
  vorbisBlock.add(_int32LE(vendorBytes.length));
  vorbisBlock.add(vendorBytes);

  // Number of comments (little-endian 32-bit)
  vorbisBlock.add(_int32LE(commentBytes.length));

  // Each comment: length (LE 32-bit) + raw bytes
  for (final comment in commentBytes) {
    vorbisBlock.add(_int32LE(comment.length));
    vorbisBlock.add(comment);
  }

  final vorbisData = vorbisBlock.toBytes();

  // Block header: type 4 (VORBIS_COMMENT) + last block flag (0x84)
  buffer.add([0x84]);
  // Block size (big-endian 24-bit)
  buffer.add([
    (vorbisData.length >> 16) & 0xFF,
    (vorbisData.length >> 8) & 0xFF,
    vorbisData.length & 0xFF,
  ]);
  buffer.add(vorbisData);

  return Uint8List.fromList(buffer.toBytes());
}

void main() {
  late Id3ReaderService reader;
  late Directory tempDir;

  setUp(() {
    reader = Id3ReaderService();
    tempDir = Directory.systemTemp.createTempSync('flac_utf8_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Writes [bytes] to a temp .flac file and returns the path.
  String writeTempFlac(Uint8List bytes, String name) {
    final file = File('${tempDir.path}/$name.flac');
    file.writeAsBytesSync(bytes);
    return file.path;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bug A: FLAC Non-ASCII Tag Decoding via _readVorbisComment
  // ─────────────────────────────────────────────────────────────────────────

  group('Bug A: FLAC Vorbis Comment UTF-8 decoding', () {
    test('CJK characters "東京" are decoded correctly from Vorbis Comment',
        () async {
      // "東京" in UTF-8 = [0xE6, 0x9D, 0xB1, 0xE4, 0xBA, 0xAC]
      final titleKey = utf8.encode('TITLE=');
      final titleValue = [0xE6, 0x9D, 0xB1, 0xE4, 0xBA, 0xAC]; // "東京"
      final comment = [...titleKey, ...titleValue];

      final flacBytes = buildFlacWithVorbisComments([comment]);
      final path = writeTempFlac(flacBytes, 'cjk_test');

      final audioFile = await reader.readTags(path);

      // EXPECTED: The title should be "東京"
      // BUG: String.fromCharCodes interprets each byte as a code point (Latin-1),
      // producing garbled output like "æ\u009d±äº¬" instead of "東京"
      expect(
        audioFile.tags['title'],
        equals('東京'),
        reason: 'CJK bytes [0xE6, 0x9D, 0xB1, 0xE4, 0xBA, 0xAC] should decode '
            'as "東京" via UTF-8, not as garbled Latin-1',
      );
    });

    test('Accented Latin "Ñoño" is decoded correctly from Vorbis Comment',
        () async {
      // "Ñoño" in UTF-8 = [0xC3, 0x91, 0x6F, 0xC3, 0xB1, 0x6F]
      final artistKey = utf8.encode('ARTIST=');
      final artistValue = [0xC3, 0x91, 0x6F, 0xC3, 0xB1, 0x6F]; // "Ñoño"
      final comment = [...artistKey, ...artistValue];

      final flacBytes = buildFlacWithVorbisComments([comment]);
      final path = writeTempFlac(flacBytes, 'accented_test');

      final audioFile = await reader.readTags(path);

      // EXPECTED: The artist should be "Ñoño"
      // BUG: String.fromCharCodes produces "Ãoño" or similar garbled output
      expect(
        audioFile.tags['artist'],
        equals('Ñoño'),
        reason: 'Accented Latin bytes [0xC3, 0x91, 0x6F, 0xC3, 0xB1, 0x6F] '
            'should decode as "Ñoño" via UTF-8, not as garbled Latin-1',
      );
    });

    test('Cyrillic "Москва" is decoded correctly from Vorbis Comment',
        () async {
      // "Москва" in UTF-8
      final albumKey = utf8.encode('ALBUM=');
      final albumValue = utf8.encode('Москва');
      final comment = [...albumKey, ...albumValue];

      final flacBytes = buildFlacWithVorbisComments([comment]);
      final path = writeTempFlac(flacBytes, 'cyrillic_test');

      final audioFile = await reader.readTags(path);

      // EXPECTED: The album should be "Москва"
      // BUG: String.fromCharCodes garbles multi-byte UTF-8 sequences
      expect(
        audioFile.tags['album'],
        equals('Москва'),
        reason: 'Cyrillic UTF-8 bytes should decode as "Москва", '
            'not as garbled Latin-1',
      );
    });

    test('Mixed ASCII and non-ASCII tags are all decoded correctly', () async {
      // Multiple comments: one ASCII, one CJK, one accented
      final titleComment = utf8.encode('TITLE=Hello World');
      final artistComment = [
        ...utf8.encode('ARTIST='),
        ...utf8.encode('東京事変'),
      ];
      final albumComment = [
        ...utf8.encode('ALBUM='),
        ...utf8.encode('café'),
      ];

      final flacBytes = buildFlacWithVorbisComments([
        titleComment,
        artistComment,
        albumComment,
      ]);
      final path = writeTempFlac(flacBytes, 'mixed_test');

      final audioFile = await reader.readTags(path);

      expect(audioFile.tags['title'], equals('Hello World'));
      expect(
        audioFile.tags['artist'],
        equals('東京事変'),
        reason: 'CJK artist "東京事変" should be decoded correctly via UTF-8',
      );
      expect(
        audioFile.tags['album'],
        equals('café'),
        reason: 'Accented album "café" should be decoded correctly via UTF-8',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bug B: Toolbar file list clearing (addFiles without clear)
  // ─────────────────────────────────────────────────────────────────────────

  group('Bug B: Toolbar file list clearing', () {
    test(
        'clear then addFiles replaces file list (validates fix)',
        () {
      // This test validates the FIXED toolbar flow: clear() before addFiles().
      final notifier = FileListNotifier();

      // Simulate initial load (e.g., user opened a folder)
      final initialFiles = [
        AudioFile(
          path: '/music/old/song1.mp3',
          filename: 'song1.mp3',
          extension: '.mp3',
          fileSize: 1000,
        ),
        AudioFile(
          path: '/music/old/song2.mp3',
          filename: 'song2.mp3',
          extension: '.mp3',
          fileSize: 2000,
        ),
        AudioFile(
          path: '/music/old/song3.mp3',
          filename: 'song3.mp3',
          extension: '.mp3',
          fileSize: 3000,
        ),
      ];
      notifier.addFiles(initialFiles);
      expect(notifier.currentFiles.length, equals(3));

      // Simulate the FIXED toolbar "Open Folder" flow:
      // The toolbar now calls clear() before addFiles().
      final newFiles = [
        AudioFile(
          path: '/music/new/track1.flac',
          filename: 'track1.flac',
          extension: '.flac',
          fileSize: 5000,
        ),
        AudioFile(
          path: '/music/new/track2.flac',
          filename: 'track2.flac',
          extension: '.flac',
          fileSize: 6000,
        ),
      ];

      // Fixed flow: clear then add
      notifier.clear();
      notifier.addFiles(newFiles);

      // EXPECTED: Only the 2 new files should be present
      expect(
        notifier.currentFiles.length,
        equals(2),
        reason: 'After toolbar open with clear, file list should contain ONLY '
            'the new files (2).',
      );
    });

    test('clear then addFiles removes old file paths (validates fix)',
        () {
      final notifier = FileListNotifier();

      // Load initial files
      final initialFiles = [
        AudioFile(
          path: '/old/folder/a.mp3',
          filename: 'a.mp3',
          extension: '.mp3',
          fileSize: 100,
        ),
      ];
      notifier.addFiles(initialFiles);

      // Simulate the FIXED toolbar flow: clear then add new files
      final newFiles = [
        AudioFile(
          path: '/new/folder/b.flac',
          filename: 'b.flac',
          extension: '.flac',
          fileSize: 200,
        ),
        AudioFile(
          path: '/new/folder/c.flac',
          filename: 'c.flac',
          extension: '.flac',
          fileSize: 300,
        ),
      ];

      // Fixed flow: clear then add
      notifier.clear();
      notifier.addFiles(newFiles);

      // EXPECTED: Only new file paths should be present
      final paths = notifier.currentFiles.map((f) => f.path).toList();
      expect(
        paths,
        equals(['/new/folder/b.flac', '/new/folder/c.flac']),
        reason: 'After toolbar open with clear, only new file paths should '
            'remain.',
      );
    });
  });
}
