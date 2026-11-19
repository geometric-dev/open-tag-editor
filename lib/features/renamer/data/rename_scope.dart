import 'package:path/path.dart' as p;

/// The result of splitting a batch of renames by the loaded folder's scope.
class RenameScopePartition {
  const RenameScopePartition({
    required this.insideRoot,
    required this.outsideRoot,
  });

  /// `originalPath -> newPath` for files whose new location is still inside
  /// [root]. These keep their place in the list, with updated paths.
  final Map<String, String> insideRoot;

  /// `originalPath -> newPath` for files whose new location is outside [root].
  /// These no longer belong to the loaded folder and should be dropped from
  /// the list (or flagged), not shown with a nonsense `../..` path.
  final Map<String, String> outsideRoot;
}

/// Splits [renames] (`originalPath -> newPath`) into those that stay within
/// [root] and those that leave it.
///
/// When [root] is null there is no scope to compare against, so every rename
/// is treated as inside the root — the caller decides what to do with that.
///
/// A file is "inside" when its new path is [root] itself or is contained by
/// it. The comparison is done on normalised, absolute paths so a relative
/// root or a mix of separators cannot produce a false result.
RenameScopePartition partitionRenamesByScope(
  Map<String, String> renames,
  String? root,
) {
  if (root == null) {
    return RenameScopePartition(insideRoot: Map.of(renames), outsideRoot: {});
  }

  final normalRoot = p.normalize(root);
  final inside = <String, String>{};
  final outside = <String, String>{};

  renames.forEach((original, target) {
    final normalTarget = p.normalize(target);
    // `p.isWithin` returns false for the parent itself, so test equality
    // separately: a file renamed to the root folder's own path is still
    // "inside" for our purposes (it just lives directly in the root).
    final isInside =
        normalTarget == normalRoot || p.isWithin(normalRoot, normalTarget);
    if (isInside) {
      inside[original] = target;
    } else {
      outside[original] = target;
    }
  });

  return RenameScopePartition(insideRoot: inside, outsideRoot: outside);
}
