import 'dart:io';

/// Detects conflicts in a batch of rename previews.
class ConflictDetector {
  /// Creates a [ConflictDetector].
  const ConflictDetector();

  /// Given a map of originalPath → targetPath, returns a map of
  /// targetPath → list of source paths that conflict (multiple sources
  /// mapping to the same target).
  ///
  /// Only entries with 2+ sources are included in the result.
  Map<String, List<String>> detectConflicts(Map<String, String> previews) {
    final groups = <String, List<String>>{};
    final caseInsensitive = Platform.isWindows;

    for (final entry in previews.entries) {
      final key = caseInsensitive ? entry.value.toLowerCase() : entry.value;
      groups.putIfAbsent(key, () => []).add(entry.key);
    }

    // We need to return the original-cased target path as the key.
    // Find the first occurrence of each target to use as the canonical key.
    final result = <String, List<String>>{};
    final keyToOriginalTarget = <String, String>{};

    for (final entry in previews.entries) {
      final key = caseInsensitive ? entry.value.toLowerCase() : entry.value;
      keyToOriginalTarget.putIfAbsent(key, () => entry.value);
    }

    for (final entry in groups.entries) {
      if (entry.value.length >= 2) {
        result[keyToOriginalTarget[entry.key]!] = entry.value;
      }
    }

    return result;
  }
}
