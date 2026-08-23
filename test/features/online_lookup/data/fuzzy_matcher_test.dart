import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher', () {
    group('similarity', () {
      test('identical strings return 1.0', () {
        expect(FuzzyMatcher.similarity('hello', 'hello'), equals(1.0));
      });

      test('completely different strings return close to 0.0', () {
        expect(FuzzyMatcher.similarity('abc', 'xyz'), lessThan(0.2));
      });

      test('"Take Me Away" vs "Take Me Away" returns 1.0', () {
        expect(
          FuzzyMatcher.similarity('Take Me Away', 'Take Me Away'),
          equals(1.0),
        );
      });

      test('empty string vs non-empty returns 0.0', () {
        expect(FuzzyMatcher.similarity('', 'hello'), equals(0.0));
        expect(FuzzyMatcher.similarity('hello', ''), equals(0.0));
      });

      test('both empty strings return 0.0', () {
        expect(FuzzyMatcher.similarity('', ''), equals(0.0));
      });

      test('case-insensitive comparison', () {
        expect(FuzzyMatcher.similarity('Hello', 'hello'), equals(1.0));
        expect(FuzzyMatcher.similarity('ABC', 'abc'), equals(1.0));
      });
    });
  });
}
