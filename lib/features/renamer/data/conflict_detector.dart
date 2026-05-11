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
      final key =
          caseInsensitive ? entry.value.toLowerCase() : entry.value;
      groups.putIfAbsent(key, () => []).add(entry.key);
    }

    // We need to return the original-cased target path as the key.
    // Find the first occurrence of each target to use as the canonical key.
    final result = <String, List<String>>{};
    final keyToOriginalTarget = <String, String>{};

    for (final entry in previews.entries) {
      final key =
          caseInsensitive ? entry.value.toLowerCase() : entry.value;
      keyToOriginalTarget.putIfAbsent(key, () => entry.value);
    }

    for (final entry in groups.entries) {
      if (entry.value.length >= 2) {
        result[keyToOriginalTarget[entry.key]!] = entry.value;
      }
    }

    return result;
  }

  /// Checks which target paths already exist on the filesystem.
  Future<Set<String>> detectExistingConflicts(Set<String> targetPaths) async {
    final existing = <String>{};

    for (final path in targetPaths) {
      if (File(path).existsSync()) {
        existing.add(path);
      }
    }

    return existing;
  }

  /// Resolves conflicts by appending numeric suffixes to make filenames unique.
  ///
  /// Given a list of target paths that conflict, returns a map of
  /// originalTargetPath → resolvedUniquePath.
  Map<String, String> autoIncrement(List<String> conflictingPaths) {
    final result = <String, String>{};
    final usedPaths = <String>{};

    for (final path in conflictingPaths) {
      final dir = _directory(path);
      final baseName = _baseName(path);
      final ext = _extension(path);

      var counter = 1;
      String candidate;

      do {
        candidate = '$dir$baseName ($counter)$ext';
        counter++;
      } while (usedPaths.contains(candidate));

      usedPaths.add(candidate);
      result[path] = candidate;
    }

    return result;
  }

  String _directory(String path) {
    final lastSep = path.lastIndexOf(Platform.pathSeparator);
    if (lastSep == -1) return '';
    return path.substring(0, lastSep + 1);
  }

  String _baseName(String path) {
    final lastSep = path.lastIndexOf(Platform.pathSeparator);
    final fileName = lastSep == -1 ? path : path.substring(lastSep + 1);
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) return fileName;
    return fileName.substring(0, dotIndex);
  }

  String _extension(String path) {
    final lastSep = path.lastIndexOf(Platform.pathSeparator);
    final fileName = lastSep == -1 ? path : path.substring(lastSep + 1);
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) return '';
    return fileName.substring(dotIndex);
  }
}
