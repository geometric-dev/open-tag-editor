import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/services/id3_reader_service.dart';

/// Preservation property tests for FLAC Vorbis Comment reading.
///
/// These tests verify that ASCII-only Vorbis Comments are read correctly
/// on the UNFIXED code. They capture the correct behavior that must be
/// preserved after the UTF-8 fix is applied.
///
/// **Validates: Requirements 3.1, 3.2, 3.5, 3.6**

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
/// Each entry in [commentBytes] should be raw bytes of a "KEY=VALUE" string.
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

/// Generates a random ASCII string of [length] using printable ASCII
/// characters (0x20–0x7E), excluding '=' which is the Vorbis Comment
/// key-value separator.
String randomAsciiValue(Random random, int length) {
  // Printable ASCII range 0x20-0x7E (space through tilde)
  return String.fromCharCodes(
    List.generate(length, (_) {
      int code;
      do {
        code = 0x20 + random.nextInt(0x7E - 0x20 + 1);
      } while (code == 0x3D); // Exclude '=' (0x3D)
      return code;
    }),
  );
}

/// Generates a random ASCII key (letters only, uppercase) of [length].
String randomAsciiKey(Random random, int length) {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  return String.fromCharCodes(
    List.generate(
      length,
      (_) => letters.codeUnitAt(random.nextInt(letters.length)),
    ),
  );
}

void main() {
  final random = Random(42); // Fixed seed for reproducibility
  late Id3ReaderService reader;
  late Directory tempDir;

  setUp(() {
    reader = Id3ReaderService();
    tempDir = Directory.systemTemp.createTempSync('flac_preservation_test_');
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

  // Known Vorbis Comment keys that map to recognized tag fields
  const knownKeys = [
    'TITLE',
    'ARTIST',
    'ALBUM',
    'DATE',
    'TRACKNUMBER',
    'GENRE',
    'COMMENT',
    'COMPOSER',
  ];

  // Corresponding internal field names after mapping
  const knownFields = [
    'title',
    'artist',
    'album',
    'year',
    'trackNumber',
    'genre',
    'comment',
    'composer',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Property 2a: ASCII Vorbis Comment Preservation
  // For 100+ random ASCII-only Vorbis Comment payloads, verify
  // _readVorbisComment output matches expected key-value pairs.
  // ─────────────────────────────────────────────────────────────────────────

  group('Property 2a: ASCII Vorbis Comment reading preserved', () {
    test(
      'random ASCII-only Vorbis Comments are read correctly (100+ iterations)',
      () async {
        for (var i = 0; i < 120; i++) {
          // Pick a random known key
          final keyIndex = random.nextInt(knownKeys.length);
          final key = knownKeys[keyIndex];
          final expectedField = knownFields[keyIndex];

          // Generate a random ASCII value (1-50 chars)
          final valueLength = 1 + random.nextInt(50);
          final value = randomAsciiValue(random, valueLength);

          // Build the comment as "KEY=VALUE" in ASCII bytes
          final commentString = '$key=$value';
          final commentBytes = commentString.codeUnits;

          // Build a FLAC file with this single comment
          final flacBytes = buildFlacWithVorbisComments([commentBytes]);
          final path = writeTempFlac(flacBytes, 'ascii_prop_$i');

          final audioFile = await reader.readTags(path);

          expect(
            audioFile.tags[expectedField],
            equals(value),
            reason:
                'Iteration $i: ASCII Vorbis Comment "$key=$value" should '
                'produce tag {$expectedField: "$value"}',
          );
        }
      },
    );

    test(
      'multiple ASCII comments in a single FLAC file are all read correctly (100+ iterations)',
      () async {
        for (var i = 0; i < 100; i++) {
          // Generate 2-4 random comments per file
          final commentCount = 2 + random.nextInt(3);
          final usedIndices = <int>{};
          final expectedTags = <String, String>{};
          final comments = <List<int>>[];

          for (var j = 0; j < commentCount; j++) {
            // Pick a unique key
            int keyIndex;
            do {
              keyIndex = random.nextInt(knownKeys.length);
            } while (usedIndices.contains(keyIndex));
            usedIndices.add(keyIndex);

            final key = knownKeys[keyIndex];
            final expectedField = knownFields[keyIndex];
            final valueLength = 1 + random.nextInt(40);
            final value = randomAsciiValue(random, valueLength);

            comments.add('$key=$value'.codeUnits.toList());
            expectedTags[expectedField] = value;
          }

          final flacBytes = buildFlacWithVorbisComments(comments);
          final path = writeTempFlac(flacBytes, 'ascii_multi_$i');

          final audioFile = await reader.readTags(path);

          for (final entry in expectedTags.entries) {
            expect(
              audioFile.tags[entry.key],
              equals(entry.value),
              reason:
                  'Iteration $i: Tag "${entry.key}" should be "${entry.value}"',
            );
          }
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 2b: utf8.decode equivalence for ASCII bytes
  // For random ASCII strings of varying lengths, verify utf8.decode(bytes)
  // equals String.fromCharCodes(bytes) — proving the fix doesn't change
  // ASCII behavior.
  // ─────────────────────────────────────────────────────────────────────────

  group('Property 2b: utf8.decode equals String.fromCharCodes for ASCII', () {
    test(
      'utf8.decode and String.fromCharCodes produce identical results for ASCII bytes (200 iterations)',
      () {
        for (var i = 0; i < 200; i++) {
          // Generate random ASCII bytes (0x20-0x7E)
          final length = 1 + random.nextInt(100);
          final bytes = List<int>.generate(
            length,
            (_) => 0x20 + random.nextInt(0x7E - 0x20 + 1),
          );

          final fromCharCodes = String.fromCharCodes(bytes);
          final fromUtf8 = utf8.decode(bytes);

          expect(
            fromUtf8,
            equals(fromCharCodes),
            reason:
                'Iteration $i: utf8.decode and String.fromCharCodes should '
                'produce identical results for ASCII bytes of length $length',
          );
        }
      },
    );

    test(
      'utf8.decode and String.fromCharCodes are equivalent for empty and single-byte ASCII',
      () {
        // Empty bytes
        expect(utf8.decode([]), equals(String.fromCharCodes([])));

        // Every single printable ASCII byte
        for (var b = 0x20; b <= 0x7E; b++) {
          final fromCharCodes = String.fromCharCodes([b]);
          final fromUtf8 = utf8.decode([b]);
          expect(
            fromUtf8,
            equals(fromCharCodes),
            reason: 'Byte 0x${b.toRadixString(16)} should decode identically',
          );
        }
      },
    );

    test(
      'utf8.decode and String.fromCharCodes match for Vorbis Comment format strings (100+ iterations)',
      () {
        for (var i = 0; i < 120; i++) {
          // Generate a "KEY=VALUE" style string using only ASCII
          final keyLength = 3 + random.nextInt(10);
          final key = randomAsciiKey(random, keyLength);
          final valueLength = 1 + random.nextInt(60);
          final value = randomAsciiValue(random, valueLength);
          final commentString = '$key=$value';
          final bytes = commentString.codeUnits;

          final fromCharCodes = String.fromCharCodes(bytes);
          final fromUtf8 = utf8.decode(bytes);

          expect(
            fromUtf8,
            equals(fromCharCodes),
            reason:
                'Iteration $i: Vorbis Comment format "$commentString" '
                'should decode identically via both methods',
          );
        }
      },
    );
  });
}
