import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tools/data/multi_value.dart';

void main() {
  group('multiValueFields', () {
    test('contains exactly the PRD fields', () {
      expect(multiValueFields, {
        'artist',
        'albumArtist',
        'genre',
        'composer',
        'conductor',
        'lyricist',
      });
    });

    test('excludes fields whose values may legitimately contain a ;', () {
      for (final field in ['title', 'comment', 'album', 'publisher']) {
        expect(
          isMultiValueField(field),
          isFalse,
          reason: '$field must not be split',
        );
      }
    });
  });

  group('parseMultiValue', () {
    test('splits a multi-value field on the semicolon convention', () {
      expect(
        parseMultiValue(
          'Rock; Alternative',
          'genre',
          splitSingleValueFields: false,
        ),
        ['Rock', 'Alternative'],
      );
    });

    test('trims whitespace around each value', () {
      expect(
        parseMultiValue(
          ' Rock ;  Alternative ',
          'genre',
          splitSingleValueFields: false,
        ),
        ['Rock', 'Alternative'],
      );
    });

    test('drops empty segments', () {
      expect(
        parseMultiValue('A; ; B', 'artist', splitSingleValueFields: false),
        ['A', 'B'],
      );
    });

    test('handles a trailing separator', () {
      expect(
        parseMultiValue('A; B;', 'artist', splitSingleValueFields: false),
        ['A', 'B'],
      );
    });

    test('parses the null-byte convention', () {
      expect(
        parseMultiValue(
          'A\u0000B',
          'artist',
          splitSingleValueFields: false,
          separator: MultiValueSeparator.nullByte,
        ),
        ['A', 'B'],
      );
    });

    test('parses the slash conventions', () {
      expect(
        parseMultiValue(
          'Artist A / Artist B',
          'artist',
          splitSingleValueFields: false,
          separator: MultiValueSeparator.slashSpaced,
        ),
        ['Artist A', 'Artist B'],
      );
      expect(
        parseMultiValue(
          'Artist A/Artist B',
          'artist',
          splitSingleValueFields: false,
          separator: MultiValueSeparator.slashTight,
        ),
        ['Artist A', 'Artist B'],
      );
    });

    test('tolerates a convention it was not configured for', () {
      // A file written by another tool should not become unreadable just
      // because this install prefers a different separator.
      expect(
        parseMultiValue(
          'A / B',
          'artist',
          splitSingleValueFields: false,
          separator: MultiValueSeparator.semicolon,
        ),
        ['A', 'B'],
      );
    });

    test('a single value yields one value', () {
      expect(parseMultiValue('Solo', 'artist', splitSingleValueFields: false), [
        'Solo',
      ]);
    });

    test('an empty string yields no values', () {
      expect(
        parseMultiValue('', 'artist', splitSingleValueFields: false),
        isEmpty,
      );
      expect(
        parseMultiValue('   ', 'artist', splitSingleValueFields: false),
        isEmpty,
      );
    });

    test('a non-multi-value field is not split by default', () {
      expect(
        parseMultiValue(
          'Rock; Alternative',
          'comment',
          splitSingleValueFields: false,
        ),
        ['Rock; Alternative'],
      );
    });

    test('a non-multi-value field is split in compatibility mode', () {
      expect(
        parseMultiValue(
          'Rock; Alternative',
          'comment',
          splitSingleValueFields: true,
        ),
        ['Rock', 'Alternative'],
      );
    });

    test(
      'a value containing a real semicolon survives in the default mode',
      () {
        expect(
          parseMultiValue(
            'AC/DC; Live',
            'title',
            splitSingleValueFields: false,
          ),
          ['AC/DC; Live'],
        );
      },
    );
  });

  group('formatMultiValue', () {
    test('joins with the configured separator', () {
      expect(
        formatMultiValue(['A', 'B'], MultiValueSeparator.semicolon),
        'A; B',
      );
      expect(
        formatMultiValue(['A', 'B'], MultiValueSeparator.nullByte),
        'A\u0000B',
      );
    });

    test('a single value needs no separator', () {
      expect(formatMultiValue(['A'], MultiValueSeparator.semicolon), 'A');
    });

    test('empty values are dropped', () {
      expect(
        formatMultiValue(['A', '', '  ', 'B'], MultiValueSeparator.semicolon),
        'A; B',
      );
    });

    test('no values yields an empty string', () {
      expect(formatMultiValue(const [], MultiValueSeparator.semicolon), '');
    });

    test('round-trips through parse', () {
      const original = ['First', 'Second', 'Third'];
      final joined = formatMultiValue(original, MultiValueSeparator.semicolon);

      expect(
        parseMultiValue(joined, 'artist', splitSingleValueFields: false),
        original,
      );
    });
  });

  group('addValue', () {
    test('appends when absent', () {
      expect(MultiValue.addValue(['A'], 'B'), ['A', 'B']);
    });

    test('does not duplicate, case-insensitively', () {
      expect(MultiValue.addValue(['Rock'], 'rock'), ['Rock']);
    });

    test('ignores a blank value', () {
      expect(MultiValue.addValue(['A'], '   '), ['A']);
    });
  });

  group('removeValue', () {
    test('removes a match, case-insensitively', () {
      expect(MultiValue.removeValue(['Rock', 'Live'], 'rock'), ['Live']);
    });

    test('leaves the list alone when absent', () {
      expect(MultiValue.removeValue(['Rock'], 'Jazz'), ['Rock']);
    });
  });

  group('replaceValue', () {
    test('replaces in place, preserving order', () {
      expect(MultiValue.replaceValue(['A', 'B', 'C'], 'B', 'Z'), [
        'A',
        'Z',
        'C',
      ]);
    });

    test('replaces every occurrence', () {
      expect(MultiValue.replaceValue(['A', 'B', 'A'], 'A', 'Z'), [
        'Z',
        'B',
        'Z',
      ]);
    });

    test('leaves the list unchanged when the value is absent', () {
      final before = ['A'];
      final result = MultiValue.replaceValue(before, 'Q', 'Z');
      expect(result, before);
    });

    test('an empty replacement removes the value', () {
      expect(MultiValue.replaceValue(['A', 'B'], 'A', ''), ['B']);
    });
  });

  group('reorder', () {
    test('moves a value later', () {
      expect(MultiValue.reorder(['A', 'B', 'C'], 0, 2), ['B', 'C', 'A']);
    });

    test('moves a value earlier', () {
      expect(MultiValue.reorder(['A', 'B', 'C'], 2, 0), ['C', 'A', 'B']);
    });

    test('a no-op reorder returns the same content', () {
      expect(MultiValue.reorder(['A', 'B'], 1, 1), ['A', 'B']);
    });

    test('out-of-range indices return the list unchanged', () {
      expect(MultiValue.reorder(['A'], -1, 0), ['A']);
      expect(MultiValue.reorder(['A'], 0, 5), ['A']);
    });
  });

  group('immutability', () {
    test('the result of a list operation is unmodifiable', () {
      final result = MultiValue.addValue(['A'], 'B');
      expect(() => result.add('C'), throwsUnsupportedError);
    });
  });
}
