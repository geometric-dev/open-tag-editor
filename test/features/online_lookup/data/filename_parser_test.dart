import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/filename_parser.dart';

void main() {
  group('FilenameParser', () {
    group('extractTrackNumber', () {
      test('extracts track number from "01_Take_Me_Away.mp3"', () {
        expect(FilenameParser.extractTrackNumber('01_Take_Me_Away.mp3'), 1);
      });

      test('extracts track number from "12 - Song Name.flac"', () {
        expect(FilenameParser.extractTrackNumber('12 - Song Name.flac'), 12);
      });

      test('returns null for "Song Without Number.mp3"', () {
        expect(
          FilenameParser.extractTrackNumber('Song Without Number.mp3'),
          isNull,
        );
      });

      test('extracts track number from "1.mp3"', () {
        expect(FilenameParser.extractTrackNumber('1.mp3'), 1);
      });

      test('extracts track number from "001_a.mp3"', () {
        expect(FilenameParser.extractTrackNumber('001_a.mp3'), 1);
      });
    });

    group('extractTitle', () {
      test('extracts title from "01_Take_Me_Away.mp3"', () {
        expect(
          FilenameParser.extractTitle('01_Take_Me_Away.mp3'),
          'Take Me Away',
        );
      });

      test('extracts title from "12 - Song Name.flac"', () {
        expect(FilenameParser.extractTitle('12 - Song Name.flac'), 'Song Name');
      });

      test('extracts title from "Song Without Number.mp3"', () {
        expect(
          FilenameParser.extractTitle('Song Without Number.mp3'),
          'Song Without Number',
        );
      });

      test('extracts title from "1.mp3"', () {
        // After removing extension → "1"; no separator follows the digit,
        // so the leading-prefix pattern does not match and "1" remains.
        expect(FilenameParser.extractTitle('1.mp3'), '1');
      });

      test('extracts title from "001_a.mp3"', () {
        expect(FilenameParser.extractTitle('001_a.mp3'), 'a');
      });
    });
  });
}
