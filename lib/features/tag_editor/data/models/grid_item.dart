import 'package:path/path.dart' as p;

import '../../../../shared/models/audio_file.dart';

/// Represents a single row in the DataGrid — either a file or a folder
/// separator.
sealed class GridItem {
  const GridItem();
}

/// A file row in the grid.
class FileGridItem extends GridItem {
  const FileGridItem({required this.file, required this.fileIndex});

  /// The audio file for this row.
  final AudioFile file;

  /// Index into the original filtered file list (for cell coordinate mapping).
  final int fileIndex;
}

/// A folder separator row in the grid.
class SeparatorGridItem extends GridItem {
  const SeparatorGridItem({required this.relativePath});

  /// The formatted relative path to display (using " / " delimiters).
  final String relativePath;
}

/// Computes the display path for a folder separator.
///
/// Returns the path of [folderPath] relative to [rootFolder], with
/// platform path separators replaced by " / " (space-slash-space).
///
/// If [folderPath] equals [rootFolder], returns just the final segment
/// of [rootFolder] (the folder's own name).
String computeRelativePath(String folderPath, String rootFolder) {
  // Strip trailing separators and normalise to a consistent separator.
  final normalised = p.normalize(folderPath);
  final normalRoot = p.normalize(rootFolder);

  // When the folder is the root itself, return just the folder name.
  if (normalised == normalRoot) {
    return p.basename(normalRoot);
  }

  // Compute the relative path from root to the folder.
  final relative = p.relative(normalised, from: normalRoot);

  // Replace platform separators with the display delimiter " / ".
  return relative.split(p.separator).join(' / ');
}
