import 'package:path/path.dart' as p;

import '../../../shared/models/audio_file.dart';
import 'models/path_scope.dart';

/// Resolves the portion of a file path to use for mask extraction based on
/// the selected [PathScope].
class PathScopeResolver {
  /// Creates a [PathScopeResolver] instance.
  const PathScopeResolver();

  /// Returns the path portion to match against the mask.
  ///
  /// - [PathScope.filenameOnly]: filename without extension
  /// - [PathScope.relativePath]: path relative to [rootFolder] without
  ///   extension
  /// - [PathScope.absolutePath]: full path without extension
  ///
  /// All returned paths use forward slashes as separators for consistent
  /// mask matching regardless of platform.
  String resolve(AudioFile file, PathScope scope, String rootFolder) {
    switch (scope) {
      case PathScope.filenameOnly:
        return p.basenameWithoutExtension(file.path);

      case PathScope.relativePath:
        final normalized = _normalizePath(file.path);
        final normalizedRoot = _normalizeRoot(rootFolder);
        final relative = normalized.startsWith(normalizedRoot)
            ? normalized.substring(normalizedRoot.length)
            : normalized;
        return _stripExtension(relative);

      case PathScope.absolutePath:
        final normalized = _normalizePath(file.path);
        return _stripExtension(normalized);
    }
  }

  /// Normalizes a file path to use forward slashes.
  String _normalizePath(String path) {
    return path.replaceAll('\\', '/');
  }

  /// Normalizes the root folder path, ensuring it ends with a forward slash.
  String _normalizeRoot(String rootFolder) {
    var normalized = rootFolder.replaceAll('\\', '/');
    if (normalized.isNotEmpty && !normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return normalized;
  }

  /// Strips the file extension from a path.
  String _stripExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    final lastSep = path.lastIndexOf('/');

    // Only strip if the dot is after the last separator (i.e., in the
    // filename portion, not in a directory name).
    if (lastDot > lastSep && lastDot > 0) {
      return path.substring(0, lastDot);
    }
    return path;
  }
}
