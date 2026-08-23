import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/settings/data/models/id3v2_version.dart';
import 'package:open_tag_editor/features/settings/data/models/tag_encoding.dart';
import 'package:open_tag_editor/features/settings/data/models/tag_write_options.dart';
import 'package:open_tag_editor/shared/services/tag_field_validator.dart';
import 'package:open_tag_editor/shared/services/taglib/taglib_types.dart';

void main() {
  const defaultOptions = TagWriteOptions(
    id3v2Version: Id3v2Version.v24,
    writeId3v1: false,
    encoding: TagEncoding.utf8,
  );

  const id3v1Options = TagWriteOptions(
    id3v2Version: Id3v2Version.v24,
    writeId3v1: true,
    encoding: TagEncoding.utf8,
  );

  const latin1Options = TagWriteOptions(
    id3v2Version: Id3v2Version.v24,
    writeId3v1: false,
    encoding: TagEncoding.latin1,
  );

  group('empty values', () {
    test('returns no issues for empty string', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: '',
        options: defaultOptions,
      );
      expect(issues, isEmpty);
    });
  });

  group('max length (10,000 chars)', () {
    test('no issue at exactly 10,000 characters', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'A' * 10000,
        options: defaultOptions,
      );
      expect(issues, isEmpty);
    });

    test('error at 10,001 characters', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'A' * 10001,
        options: defaultOptions,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.error);
      expect(issues.first.message, contains('10000'));
    });

    test('error includes actual length in message', () {
      final issues = TagFieldValidator.validate(
        field: 'artist',
        value: 'B' * 15000,
        options: defaultOptions,
      );
      expect(issues.first.message, contains('15000'));
    });
  });

  group('ID3v1 truncation warning', () {
    test('no warning when writeId3v1 is false', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'A' * 50,
        options: defaultOptions,
      );
      expect(issues, isEmpty);
    });

    test('no warning at exactly 30 characters', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'A' * 30,
        options: id3v1Options,
      );
      expect(issues, isEmpty);
    });

    test('warning at 31 characters', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'A' * 31,
        options: id3v1Options,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.warning);
      expect(issues.first.message, contains('30'));
      expect(issues.first.message, contains('truncated'));
    });

    test('year field warns at 5 characters (limit is 4)', () {
      final issues = TagFieldValidator.validate(
        field: 'year',
        value: '20241',
        options: id3v1Options,
      );
      // Should have ID3v1 truncation warning (and possibly numeric warning)
      final truncationIssues =
          issues.where((i) => i.message.contains('truncated')).toList();
      expect(truncationIssues, hasLength(1));
      expect(truncationIssues.first.message, contains('4'));
    });

    test('year field no warning at 4 characters', () {
      final issues = TagFieldValidator.validate(
        field: 'year',
        value: '2024',
        options: id3v1Options,
      );
      expect(issues, isEmpty);
    });

    test('applies to all text fields', () {
      for (final field in ['title', 'artist', 'album', 'comment', 'genre']) {
        final issues = TagFieldValidator.validate(
          field: field,
          value: 'X' * 31,
          options: id3v1Options,
        );
        expect(
          issues.any((i) => i.message.contains('truncated')),
          isTrue,
          reason: '$field should warn about truncation',
        );
      }
    });
  });

  group('Latin-1 encoding errors', () {
    test('no error for pure ASCII', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'Hello World 123',
        options: latin1Options,
      );
      expect(issues, isEmpty);
    });

    test('no error for Latin-1 characters (0x00-0xFF)', () {
      // Characters like ñ (0xF1), ü (0xFC), é (0xE9) are valid Latin-1
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'Ñoño Café Naïve',
        options: latin1Options,
      );
      expect(issues, isEmpty);
    });

    test('error for CJK characters', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: '東京',
        options: latin1Options,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.error);
      expect(issues.first.message, contains('Latin-1'));
    });

    test('error for Cyrillic characters', () {
      final issues = TagFieldValidator.validate(
        field: 'artist',
        value: 'Чайковский',
        options: latin1Options,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.error);
    });

    test('error for emoji', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: '🎵 Music',
        options: latin1Options,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.error);
    });

    test('no error when encoding is UTF-8', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: '東京 🎵 Чайковский',
        options: defaultOptions,
      );
      expect(issues, isEmpty);
    });

    test('shows preview of non-Latin-1 characters in message', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'Hello 東京',
        options: latin1Options,
      );
      expect(issues.first.message, contains('東'));
    });

    test('truncates preview at 5 characters', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'あいうえおかきくけこ',
        options: latin1Options,
      );
      expect(issues.first.message, contains('…'));
    });
  });

  group('numeric field validation', () {
    test('no warning for valid integer', () {
      final issues = TagFieldValidator.validate(
        field: 'trackNumber',
        value: '5',
        options: defaultOptions,
      );
      expect(issues, isEmpty);
    });

    test('no warning for track/disc format "3/12"', () {
      final issues = TagFieldValidator.validate(
        field: 'trackNumber',
        value: '3/12',
        options: defaultOptions,
      );
      expect(issues, isEmpty);
    });

    test('warning for non-numeric text in trackNumber', () {
      final issues = TagFieldValidator.validate(
        field: 'trackNumber',
        value: 'five',
        options: defaultOptions,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.warning);
      expect(issues.first.message, contains('numeric'));
    });

    test('warning for non-numeric text in year', () {
      final issues = TagFieldValidator.validate(
        field: 'year',
        value: '202x',
        options: defaultOptions,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.warning);
    });

    test('warning for non-numeric text in bpm', () {
      final issues = TagFieldValidator.validate(
        field: 'bpm',
        value: 'fast',
        options: defaultOptions,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.warning);
    });

    test('no warning for non-numeric fields like title', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'Not a number',
        options: defaultOptions,
      );
      expect(issues, isEmpty);
    });

    test('no warning for discNumber with slash format', () {
      final issues = TagFieldValidator.validate(
        field: 'discNumber',
        value: '1/2',
        options: defaultOptions,
      );
      expect(issues, isEmpty);
    });
  });

  group('combined issues', () {
    test('ID3v1 truncation + Latin-1 error reported together', () {
      const options = TagWriteOptions(
        id3v2Version: Id3v2Version.v24,
        writeId3v1: true,
        encoding: TagEncoding.latin1,
      );
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: '東京事変 - 群青日和 - A Very Long Title That Exceeds Thirty',
        options: options,
      );
      // Should have both truncation warning and Latin-1 error
      expect(issues.length, greaterThanOrEqualTo(2));
      expect(
        issues.any((i) => i.severity == TagFieldSeverity.warning),
        isTrue,
      );
      expect(
        issues.any((i) => i.severity == TagFieldSeverity.error),
        isTrue,
      );
    });

    test('max length + ID3v1 truncation reported together', () {
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'A' * 10001,
        options: id3v1Options,
      );
      expect(issues.length, equals(2));
    });

    test('numeric warning + ID3v1 truncation for long non-numeric year', () {
      final issues = TagFieldValidator.validate(
        field: 'year',
        value: 'circa 2024',
        options: id3v1Options,
      );
      // Should have numeric warning + ID3v1 truncation (>4 chars)
      expect(issues.length, equals(2));
    });
  });

  group('tagFormat parameter', () {
    test('validation works regardless of tagFormat', () {
      // tagFormat is reserved for future format-specific rules
      final issues = TagFieldValidator.validate(
        field: 'title',
        value: 'A' * 31,
        options: id3v1Options,
        tagFormat: TagFormat.vorbisComment,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, TagFieldSeverity.warning);
    });
  });
}
