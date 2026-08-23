/// Computes fuzzy string similarity for title matching.
class FuzzyMatcher {
  FuzzyMatcher._();

  /// Computes a normalised similarity score between two strings.
  ///
  /// Uses Levenshtein distance normalised by the longer string's length.
  /// Returns a value in [0.0, 1.0] where 1.0 is an exact match.
  /// Comparison is case-insensitive.
  ///
  /// Edge cases:
  /// - Both strings empty → 0.0
  /// - One string empty → 0.0
  /// - Identical strings → 1.0
  static double similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    final lowerA = a.toLowerCase();
    final lowerB = b.toLowerCase();

    if (lowerA == lowerB) return 1.0;

    final maxLength =
        lowerA.length > lowerB.length ? lowerA.length : lowerB.length;
    final distance = _levenshteinDistance(lowerA, lowerB);

    return 1.0 - (distance / maxLength);
  }

  /// Computes the Levenshtein edit distance between two strings using
  /// dynamic programming with O(min(m, n)) space.
  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Ensure a is the shorter string for space optimisation.
    if (a.length > b.length) {
      final temp = a;
      a = b;
      b = temp;
    }

    final m = a.length;
    final n = b.length;

    // Use two rows instead of full matrix.
    var previousRow = List<int>.generate(m + 1, (i) => i);
    var currentRow = List<int>.filled(m + 1, 0);

    for (var j = 1; j <= n; j++) {
      currentRow[0] = j;

      for (var i = 1; i <= m; i++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        currentRow[i] = [
          currentRow[i - 1] + 1, // insertion
          previousRow[i] + 1, // deletion
          previousRow[i - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }

      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[m];
  }
}
