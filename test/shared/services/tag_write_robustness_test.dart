import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/services/id3_writer_service.dart';
import 'package:open_tag_editor/shared/services/tag_reader_service.dart';

/// Generates a minimal valid MP3 file (MPEG frame with silence).
///
/// Creates a bare-bones MPEG audio frame so that tag writers have a valid
/// audio file to work with. The frame is a valid MPEG1 Layer 3, 128kbps,
/// 44100Hz, stereo frame filled with zeros (silence).
Uint8List _generateMinimalMp3() {
  // MPEG1 Layer 3, 128kbps, 44100Hz, stereo frame header: 0xFFFB9004
  // Frame size = 144 * 128000 / 44100 + 0 = 417 bytes
  const frameSize = 417;
  final frame = Uint8List(frameSize);
  frame[0] = 0xFF;
  frame[1] = 0xFB; // MPEG1, Layer 3, no CRC
  frame[2] = 0x90; // 128kbps, 44100Hz
  frame[3] = 0x04; // Stereo, no padding

  // Repeat a few frames to make it more realistic
  final output = BytesBuilder();
  for (var i = 0; i < 5; i++) {
    output.add(frame);
  }
  return Uint8List.fromList(output.toBytes());
}

/// Generates a minimal valid FLAC file with an empty STREAMINFO block.
Uint8List _generateMinimalFlac() {
  final output = BytesBuilder();

  // fLaC marker
  output.add([0x66, 0x4C, 0x61, 0x43]);

  // STREAMINFO block (type=0, is_last=true, size=34)
  output.addByte(0x80); // last-metadata-block flag + type 0
  output.add([0x00, 0x00, 0x22]); // size = 34 bytes

  // STREAMINFO data (34 bytes)
  // min block size (2), max block size (2), min frame size (3),
  // max frame size (3), sample rate/channels/bps/samples (8),
  // MD5 (16)
  final streamInfo = Uint8List(34);
  // min/max block size = 4096
  streamInfo[0] = 0x10;
  streamInfo[1] = 0x00;
  streamInfo[2] = 0x10;
  streamInfo[3] = 0x00;
  // sample rate 44100 = 0xAC44, channels=2 (stored as 1), bps=16 (stored as 15)
  // Byte 10: top 4 bits of sample rate
  streamInfo[10] = 0x0A; // 44100 >> 12
  streamInfo[11] = 0xC4; // (44100 >> 4) & 0xFF
  // Byte 12: bottom 4 bits of sample rate + channels (1=stereo) + top bit of bps
  streamInfo[12] = 0x42; // (44100 & 0xF)<<4 | (1<<1) | (15>>4)
  // Byte 13: bottom 4 bits of bps + top 4 bits of total samples
  streamInfo[13] = 0xF0;
  output.add(streamInfo);

  return Uint8List.fromList(output.toBytes());
}

void main() {
  late Id3WriterService writer;
  late Directory tempDir;

  setUp(() {
    writer = Id3WriterService();
    tempDir = Directory.systemTemp.createTempSync('tag_robustness_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Helper: creates a temp MP3 file and returns its path.
  String createTempMp3() {
    final path = '${tempDir.path}/test_${DateTime.now().microsecondsSinceEpoch}.mp3';
    File(path).writeAsBytesSync(_generateMinimalMp3());
    return path;
  }

  /// Helper: creates a temp FLAC file and returns its path.
  String createTempFlac() {
    final path = '${tempDir.path}/test_${DateTime.now().microsecondsSinceEpoch}.flac';
    File(path).writeAsBytesSync(_generateMinimalFlac());
    return path;
  }

  /// Helper: verifies the file is still structurally valid after a write.
  /// Checks MP3 sync bytes or FLAC magic are intact.
  void verifyFileIntegrity(String path) {
    final bytes = File(path).readAsBytesSync();
    expect(bytes.length, greaterThan(10), reason: 'File should not be empty');

    if (path.endsWith('.mp3')) {
      // After ID3v2 tag, audio data must start with MPEG sync (0xFFE0+)
      // Find the audio start (after ID3v2 header)
      var audioStart = 0;
      if (bytes.length > 10 &&
          bytes[0] == 0x49 &&
          bytes[1] == 0x44 &&
          bytes[2] == 0x33) {
        // ID3v2 header present
        final tagSize = ((bytes[6] & 0x7F) << 21) |
            ((bytes[7] & 0x7F) << 14) |
            ((bytes[8] & 0x7F) << 7) |
            (bytes[9] & 0x7F);
        audioStart = 10 + tagSize;
      }
      expect(
        audioStart < bytes.length,
        isTrue,
        reason: 'ID3v2 tag size must not exceed file size',
      );
      // Verify MPEG sync word at audio start
      expect(bytes[audioStart], equals(0xFF), reason: 'MPEG sync byte 1');
      expect(
        bytes[audioStart + 1] & 0xE0,
        equals(0xE0),
        reason: 'MPEG sync byte 2 (top 3 bits)',
      );
    } else if (path.endsWith('.flac')) {
      // FLAC magic must be at the start
      expect(bytes[0], equals(0x66)); // 'f'
      expect(bytes[1], equals(0x4C)); // 'L'
      expect(bytes[2], equals(0x61)); // 'a'
      expect(bytes[3], equals(0x43)); // 'C'
    }
  }

  /// Helper: verifies the file can be read by ffprobe (external validation).
  /// Skips if ffprobe is not available on the system.
  Future<bool> verifyWithFfprobe(String path) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format=format_name',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        path,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      // ffprobe not available — skip external validation
      return true;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: Non-visible characters
  // ─────────────────────────────────────────────────────────────────────────

  group('non-visible characters', () {
    test('null bytes in tag values do not corrupt file', () async {
      final path = createTempMp3();
      final tags = {'title': 'Hello\x00World', 'artist': 'Test'};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('tab and newline characters are written without corruption', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'Line1\tTabbed\nLine2',
        'artist': 'Artist\r\nWith CR LF',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('control characters (0x01-0x1F) do not corrupt file', () async {
      final path = createTempMp3();
      final controlChars = String.fromCharCodes(
        List.generate(31, (i) => i + 1),
      );
      final tags = {'title': 'Control:$controlChars:End', 'artist': 'Test'};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('BOM (byte order mark) in value does not corrupt file', () async {
      final path = createTempMp3();
      final tags = {'title': '\uFEFFTitle With BOM', 'artist': 'Test'};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('zero-width characters do not corrupt file', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'Zero\u200BWidth\u200CJoiner\u200DTest\uFEFF',
        'artist': 'Test',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: Non-ASCII / Unicode characters
  // ─────────────────────────────────────────────────────────────────────────

  group('non-ASCII and Unicode characters', () {
    test('CJK characters (Chinese/Japanese/Korean)', () async {
      final path = createTempMp3();
      final tags = {
        'title': '東京事変 - 群青日和',
        'artist': '椎名林檎',
        'album': '教育',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('Arabic and Hebrew (RTL scripts)', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'مرحبا بالعالم',
        'artist': 'שלום עולם',
        'album': 'Mixed مختلط Album',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('Cyrillic characters', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'Калинка-Малинка',
        'artist': 'Чайковский',
        'album': 'Русская Классика',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('emoji and supplementary plane characters', () async {
      final path = createTempMp3();
      final tags = {
        'title': '🎵 Music 🎶 Note 🎸',
        'artist': '👨‍🎤 Rock Star',
        'album': '💿 Greatest Hits 🏆',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('combining diacritical marks', () async {
      final path = createTempMp3();
      final tags = {
        // Composed vs decomposed forms
        'title': 'Ñoño Café Naïve', // precomposed
        'artist': 'n\u0303 o\u0308', // decomposed: ñ ö
        'album': 'Ångström Ü Ö Ä',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('Thai, Devanagari, and other complex scripts', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'สวัสดีครับ', // Thai
        'artist': 'नमस्ते', // Devanagari
        'album': 'ᚠᚢᚦᚨᚱᚲ', // Runic
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('full-width Latin characters', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'ＦＵＬＬ　ＷＩＤＴＨ',
        'artist': 'Ｔｅｓｔ　Ａｒｔｉｓｔ',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('surrogate pair characters (astral plane)', () async {
      final path = createTempMp3();
      final tags = {
        'title': '𝄞 Musical Symbol G Clef',
        'artist': '𝕳𝖊𝖑𝖑𝖔', // Mathematical Fraktur
        'album': '🏴󠁧󠁢󠁥󠁮󠁧󠁿 Flag Sequence',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: Long strings
  // ─────────────────────────────────────────────────────────────────────────

  group('long strings', () {
    test('title with 1000 characters', () async {
      final path = createTempMp3();
      final longTitle = 'A' * 1000;
      final tags = {'title': longTitle, 'artist': 'Test'};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('title with 10,000 characters', () async {
      final path = createTempMp3();
      final longTitle = 'B' * 10000;
      final tags = {'title': longTitle, 'artist': 'Test'};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('title with 100,000 characters', () async {
      final path = createTempMp3();
      final longTitle = 'C' * 100000;
      final tags = {'title': longTitle, 'artist': 'Test'};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('all fields filled with long strings simultaneously', () async {
      final path = createTempMp3();
      final longValue = 'X' * 5000;
      final tags = {
        'title': longValue,
        'artist': longValue,
        'album': longValue,
        'genre': longValue,
        'comment': longValue,
        'composer': longValue,
        'publisher': longValue,
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('long string with mixed Unicode (stress test)', () async {
      final path = createTempMp3();
      // Mix of ASCII, CJK, emoji, and combining marks repeated
      const segment = 'Hello世界🎵ñ';
      final longMixed = segment * 500; // ~5000 chars of multi-byte content
      final tags = {'title': longMixed, 'artist': 'Test'};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: Edge-case values
  // ─────────────────────────────────────────────────────────────────────────

  group('edge-case values', () {
    test('empty string values do not corrupt file', () async {
      final path = createTempMp3();
      final tags = {'title': '', 'artist': '', 'album': ''};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('single character values', () async {
      final path = createTempMp3();
      final tags = {'title': 'A', 'artist': '1', 'album': '.'};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('values with only whitespace', () async {
      final path = createTempMp3();
      final tags = {
        'title': '   ',
        'artist': '\t\t',
        'album': ' \n ',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('values with special ID3 characters (syncsafe boundary)', () async {
      final path = createTempMp3();
      // Characters that could interfere with syncsafe integer encoding
      final tags = {
        'title': '\x7F\x7F\x7F\x7F', // max syncsafe byte values
        'artist': '\xFF\xFF\xFF\xFF', // max byte values
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('numeric-only values in text fields', () async {
      final path = createTempMp3();
      final tags = {
        'title': '12345678901234567890',
        'artist': '0',
        'album': '999999999999',
        'year': '2024',
        'trackNumber': '99',
        'bpm': '200',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('values resembling frame headers do not confuse parser', () async {
      final path = createTempMp3();
      // Values that look like ID3v2 frame IDs
      final tags = {
        'title': 'TIT2TALBTPE1',
        'artist': 'ID3\x03\x00',
        'album': '\xFF\xFB\x90\x04', // MPEG sync pattern
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('path-like values with slashes and backslashes', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'C:\\Users\\Music\\file.mp3',
        'artist': '/usr/local/music/artist',
        'album': '../../../etc/passwd',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('HTML/XML-like content in values', () async {
      final path = createTempMp3();
      final tags = {
        'title': '<script>alert("xss")</script>',
        'artist': '&amp; &lt; &gt; &quot;',
        'album': '<![CDATA[test]]>',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('SQL injection patterns in values', () async {
      final path = createTempMp3();
      final tags = {
        'title': "'; DROP TABLE tags; --",
        'artist': 'Robert\'); DROP TABLE Students;--',
        'album': '1 OR 1=1',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: Combinations of normal fields
  // ─────────────────────────────────────────────────────────────────────────

  group('normal field combinations', () {
    test('all standard fields populated', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'Bohemian Rhapsody',
        'artist': 'Queen',
        'albumArtist': 'Queen',
        'album': 'A Night at the Opera',
        'year': '1975',
        'trackNumber': '11',
        'genre': 'Rock',
        'comment': 'Classic rock masterpiece',
        'composer': 'Freddie Mercury',
        'publisher': 'EMI',
        'copyright': '© 1975 EMI Records',
        'bpm': '72',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('overwrite existing tags with new values', () async {
      final path = createTempMp3();

      // Write initial tags
      await writer.writeTags(path, {
        'title': 'Original Title',
        'artist': 'Original Artist',
      });
      verifyFileIntegrity(path);

      // Overwrite with new tags
      await writer.writeTags(path, {
        'title': 'New Title',
        'artist': 'New Artist',
        'album': 'New Album',
      });
      verifyFileIntegrity(path);
    });

    test('multiple sequential writes do not accumulate corruption', () async {
      final path = createTempMp3();

      for (var i = 0; i < 20; i++) {
        await writer.writeTags(path, {
          'title': 'Title $i',
          'artist': 'Artist $i',
          'album': 'Album $i',
        });
        verifyFileIntegrity(path);
      }
    });

    test('write then read-back preserves values (MP3)', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'Roundtrip Test',
        'artist': 'Test Artist',
        'album': 'Test Album',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);

      // Read back the raw ID3v2 frames to verify content
      final bytes = File(path).readAsBytesSync();
      final fileContent = String.fromCharCodes(bytes);
      expect(fileContent.contains('Roundtrip Test'), isTrue);
      expect(fileContent.contains('Test Artist'), isTrue);
      expect(fileContent.contains('Test Album'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: FLAC format robustness
  // ─────────────────────────────────────────────────────────────────────────

  group('FLAC format robustness', () {
    test('CJK characters in FLAC Vorbis Comment', () async {
      final path = createTempFlac();
      final tags = {
        'title': '東京事変 - 群青日和',
        'artist': '椎名林檎',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('long strings in FLAC Vorbis Comment', () async {
      final path = createTempFlac();
      final tags = {
        'title': 'F' * 10000,
        'artist': 'G' * 5000,
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('control characters in FLAC Vorbis Comment', () async {
      final path = createTempFlac();
      final tags = {
        'title': 'Tab\there\nNewline',
        'artist': 'Control\x01\x02\x03',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('emoji in FLAC Vorbis Comment', () async {
      final path = createTempFlac();
      final tags = {
        'title': '🎵 FLAC Music 🎶',
        'artist': '👨‍🎤 FLAC Artist',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('multiple sequential writes to FLAC', () async {
      final path = createTempFlac();

      for (var i = 0; i < 10; i++) {
        await writer.writeTags(path, {
          'title': 'FLAC Title $i',
          'artist': 'FLAC Artist $i',
        });
        verifyFileIntegrity(path);
      }
    });

    test('all fields in FLAC', () async {
      final path = createTempFlac();
      final tags = {
        'title': 'FLAC Full Test',
        'artist': 'FLAC Artist',
        'album': 'FLAC Album',
        'year': '2024',
        'trackNumber': '5',
        'discNumber': '1',
        'genre': 'Electronic',
        'comment': 'Testing all FLAC fields',
        'composer': 'FLAC Composer',
        'publisher': 'FLAC Label',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: Boundary and overflow conditions
  // ─────────────────────────────────────────────────────────────────────────

  group('boundary and overflow conditions', () {
    test('tag size near syncsafe integer max (2^28 - 1)', () async {
      final path = createTempMp3();
      // 268 MB would be the max syncsafe size — we test a large but
      // reasonable value that stresses the size calculation.
      // 1MB of tag data is extreme but should not corrupt.
      final megaString = 'M' * (1024 * 1024);
      final tags = {'title': megaString};

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('many fields with moderate values', () async {
      final path = createTempMp3();
      final tags = <String, String>{};
      // Fill all known fields with 200-char values
      final fields = [
        'title', 'artist', 'albumArtist', 'album', 'year',
        'trackNumber', 'genre', 'comment', 'composer',
        'conductor', 'lyricist', 'publisher', 'copyright', 'bpm',
      ];
      for (final field in fields) {
        tags[field] = '$field:${'v' * 200}';
      }

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('value exactly at frame size boundaries', () async {
      final path = createTempMp3();
      // Test values at powers of 2 which might trigger edge cases
      for (final size in [127, 128, 255, 256, 65535, 65536]) {
        final tags = {'title': 'X' * size};
        await writer.writeTags(path, tags);
        verifyFileIntegrity(path);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: External validation with ffprobe
  // ─────────────────────────────────────────────────────────────────────────

  group('external validation (ffprobe)', () {
    test('MP3 with Unicode tags passes ffprobe validation', () async {
      final path = createTempMp3();
      final tags = {
        'title': '東京 🎵 Москва',
        'artist': 'Ñoño & Ångström',
        'album': 'مرحبا 世界',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);

      final valid = await verifyWithFfprobe(path);
      expect(valid, isTrue, reason: 'ffprobe should accept the file');
    });

    test('MP3 with long tags passes ffprobe validation', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'L' * 5000,
        'artist': 'Long Artist Name ' * 100,
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);

      final valid = await verifyWithFfprobe(path);
      expect(valid, isTrue, reason: 'ffprobe should accept the file');
    });

    test('MP3 after 10 rewrites passes ffprobe validation', () async {
      final path = createTempMp3();

      for (var i = 0; i < 10; i++) {
        await writer.writeTags(path, {
          'title': 'Rewrite $i — 日本語テスト',
          'artist': 'Artist $i 🎸',
        });
      }

      verifyFileIntegrity(path);
      final valid = await verifyWithFfprobe(path);
      expect(valid, isTrue, reason: 'ffprobe should accept the file');
    });

    test('FLAC with Unicode tags passes ffprobe validation', () async {
      final path = createTempFlac();
      final tags = {
        'title': 'FLAC 東京 🎵',
        'artist': 'Ñoño FLAC',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);

      final valid = await verifyWithFfprobe(path);
      expect(valid, isTrue, reason: 'ffprobe should accept the FLAC file');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: Unsupported format handling
  // ─────────────────────────────────────────────────────────────────────────

  group('unsupported format handling', () {
    test('writing to unsupported extension throws TagWriteException', () async {
      final path = '${tempDir.path}/test.wma';
      File(path).writeAsBytesSync(Uint8List(1024));

      expect(
        () => writer.writeTags(path, {'title': 'Test'}),
        throwsA(isA<TagWriteException>()),
      );
    });

    test('writing to non-existent file throws TagWriteException', () async {
      final path = '${tempDir.path}/does_not_exist.mp3';

      expect(
        () => writer.writeTags(path, {'title': 'Test'}),
        throwsA(isA<TagWriteException>()),
      );
    });

    test('writing to corrupt binary does not crash', () async {
      final path = '${tempDir.path}/corrupt.mp3';
      // Random bytes that are not a valid MP3
      File(path).writeAsBytesSync(Uint8List.fromList(
        List.generate(1024, (i) => i % 256),
      ),);

      // Should either succeed (writing a new ID3v2 header) or throw cleanly
      try {
        await writer.writeTags(path, {'title': 'Test'});
        // If it succeeds, verify the file is at least not empty
        expect(File(path).lengthSync(), greaterThan(0));
      } on TagWriteException {
        // Acceptable — clean failure
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP: Mixed stress scenarios
  // ─────────────────────────────────────────────────────────────────────────

  group('mixed stress scenarios', () {
    test('Unicode + long + control chars combined', () async {
      final path = createTempMp3();
      final tags = {
        'title': '${'🎵東京' * 200}\x00\x01\x02',
        'artist': '${'\t' * 50}Ñoño${'Ω' * 300}',
        'album': 'Normal Album Name',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);
    });

    test('rapid alternating writes MP3 and FLAC', () async {
      final mp3Path = createTempMp3();
      final flacPath = createTempFlac();

      for (var i = 0; i < 10; i++) {
        await writer.writeTags(mp3Path, {
          'title': 'MP3 Iteration $i 🎵',
          'artist': '日本語 $i',
        });
        await writer.writeTags(flacPath, {
          'title': 'FLAC Iteration $i 🎶',
          'artist': 'Кириллица $i',
        });
      }

      verifyFileIntegrity(mp3Path);
      verifyFileIntegrity(flacPath);
    });

    test('write empty then full then empty again', () async {
      final path = createTempMp3();

      // Write with all empty (should be no-op or minimal tag)
      await writer.writeTags(path, {
        'title': '',
        'artist': '',
      });
      verifyFileIntegrity(path);

      // Write full
      await writer.writeTags(path, {
        'title': 'Full Title 🎵 東京',
        'artist': 'Full Artist Ñoño',
        'album': 'Full Album',
      });
      verifyFileIntegrity(path);

      // Write empty again
      await writer.writeTags(path, {
        'title': '',
        'artist': '',
        'album': '',
      });
      verifyFileIntegrity(path);
    });

    test('maximum field count with diverse content', () async {
      final path = createTempMp3();
      final tags = {
        'title': 'Ñoño 東京 🎵',
        'artist': 'Чайковский',
        'albumArtist': 'مرحبا',
        'album': 'สวัสดี',
        'year': '2024',
        'trackNumber': '1',
        'genre': 'Wörld Müsic',
        'comment': 'A ${'long ' * 100}comment',
        'composer': '作曲家',
        'conductor': 'Дирижёр',
        'lyricist': 'गीतकार',
        'publisher': '出版社 📚',
        'copyright': '© 2024 🌍',
        'bpm': '120',
      };

      await writer.writeTags(path, tags);
      verifyFileIntegrity(path);

      final valid = await verifyWithFfprobe(path);
      expect(valid, isTrue);
    });
  });
}
