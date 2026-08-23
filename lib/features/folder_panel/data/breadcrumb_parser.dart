import 'package:path/path.dart' as p;

/// Pure-function utilities for breadcrumb path manipulation.
///
/// Splits folder paths into navigable segments and reconstructs paths
/// from segment indices. Used by the [BreadcrumbBar] widget to render
/// clickable path segments and handle ancestor navigation.
class BreadcrumbParser {
  /// Creates a [BreadcrumbParser] using the given path [context].
  ///
  /// Defaults to the current platform's path context if not specified.
  /// Accepting a context parameter enables testing with both Windows
  /// and POSIX path styles.
  const BreadcrumbParser([this._context]);

  final p.Context? _context;

  p.Context get _ctx => _context ?? p.context;

  /// Splits [folderPath] into individual path segments.
  ///
  /// On Windows, the first segment is the drive letter (e.g., "C:").
  /// Returns an empty list for empty paths.
  ///
  /// Example (Windows): `C:\Users\Music` → `['C:', 'Users', 'Music']`
  /// Example (POSIX): `/home/user/music` → `['/', 'home', 'user', 'music']`
  List<String> splitSegments(String folderPath) {
    if (folderPath.isEmpty) {
      return [];
    }

    final parts = _ctx.split(folderPath);
    if (parts.isEmpty) {
      return [];
    }

    return parts;
  }

  /// Reconstructs the full path from segments [0..[index]] inclusive.
  ///
  /// Joins segments with the platform path separator. The [segments] list
  /// should be the output of [splitSegments]. The [index] must be a valid
  /// index within [segments].
  ///
  /// Example (Windows): `pathAtIndex(['C:', 'Users', 'Music'], 1)` → `C:\Users`
  /// Example (POSIX): `pathAtIndex(['/', 'home', 'user'], 1)` → `/home`
  String pathAtIndex(List<String> segments, int index) {
    if (segments.isEmpty || index < 0 || index >= segments.length) {
      return '';
    }

    final subSegments = segments.sublist(0, index + 1);
    return _ctx.joinAll(subSegments);
  }
}
