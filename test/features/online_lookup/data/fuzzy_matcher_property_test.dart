import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/fuzzy_matcher.dart';

/// Property-based tests for FuzzyMatcher.
///
/// Each property is tested with 100+ random inputs to verify the invariant
/// holds across the input space.
void main() {
  final random = Random(42); // Fixed seed for reproducibility

  /// Generates a random non-empty string of length 1–50 using ASCII
  /// characters in the range 0x41–0x7A (includes uppercase and lowercase).
  String randomString(int length) {
    const minChar = 0x41; // 'A'
    const maxChar = 0x7A; // 'z'
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => minChar + random.nextInt(maxChar - minChar + 1),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Property 3: Fuzzy similarity is case-insensitive
  // Feature: partial-album-match, Property 3: Fuzzy similarity is case-insensitive
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 2.2**
  group('Property 3: Fuzzy similarity is case-insensitive', () {
    test(
      'similarity(a, b) equals similarity(a.toUpperCase(), b.toLowerCase())',
      () {
        for (var i = 0; i < 100; i++) {
          final lengthA = 1 + random.nextInt(50);
          final lengthB = 1 + random.nextInt(50);
          final a = randomString(lengthA);
          final b = randomString(lengthB);

          final score1 = FuzzyMatcher.similarity(a, b);
          final score2 = FuzzyMatcher.similarity(
            a.toUpperCase(),
            b.toLowerCase(),
          );

          expect(
            score1,
            closeTo(score2, 1e-10),
            reason: 'similarity("$a", "$b") = $score1 should equal '
                'similarity("${a.toUpperCase()}", "${b.toLowerCase()}") = '
                '$score2 (iteration $i)',
          );
        }
      },
    );
  });
}
