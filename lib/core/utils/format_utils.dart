import 'package:path/path.dart' as p;

/// Utility functions for formatting display values.
class FormatUtils {
  FormatUtils._();

  /// Formats duration in seconds to "mm:ss" or "h:mm:ss".
  ///
  /// Returns empty string if [seconds] is null or <= 0.
  /// Uses "mm:ss" for durations under 1 hour, "h:mm:ss" for 1 hour or more.
  static String formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final totalSeconds = seconds.round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Formats total duration for status bar display as "Xh Ym".
  ///
  /// Returns "0m" if [totalSeconds] is 0 or negative.
  static String formatTotalDuration(double totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final h = totalSeconds ~/ 3600;
    final m = ((totalSeconds % 3600) ~/ 60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Formats file size in bytes to human-readable string.
  ///
  /// Uses B, KB, MB, GB units with appropriate precision.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Computes the relative path of [filePath] from [rootFolder].
  ///
  /// Returns the file path relative to the root folder.
  /// If [filePath] is not under [rootFolder], returns the full filename.
  static String computeRelativePath(String filePath, String rootFolder) {
    try {
      return p.relative(filePath, from: rootFolder);
    } catch (_) {
      return p.basename(filePath);
    }
  }

  /// Computes the common parent directory of a list of file paths.
  ///
  /// Returns the longest common directory prefix shared by all paths.
  /// Returns empty string if [paths] is empty.
  static String computeCommonParentDirectory(List<String> paths) {
    if (paths.isEmpty) return '';
    if (paths.length == 1) return p.dirname(paths.first);

    final directories = paths.map((path) => p.dirname(path)).toList();
    final parts = p.split(directories.first);
    var commonLength = parts.length;

    for (var i = 1; i < directories.length; i++) {
      final otherParts = p.split(directories[i]);
      var matchLength = 0;
      final maxCheck =
          commonLength < otherParts.length ? commonLength : otherParts.length;
      for (var j = 0; j < maxCheck; j++) {
        if (parts[j] == otherParts[j]) {
          matchLength++;
        } else {
          break;
        }
      }
      commonLength = matchLength;
    }

    if (commonLength == 0) return '';
    return p.joinAll(parts.sublist(0, commonLength));
  }
}
