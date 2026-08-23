import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/models/audio_file.dart';
import '../../presentation/widgets/address_bar.dart';
import '../models/grid_item.dart';
import 'filtered_sorted_file_list_provider.dart';
import 'recursive_loading_provider.dart';
import 'sort_state_provider.dart';

/// Provides the computed list of grid items for the DataGrid.
///
/// Reactively recomputes when the file list, recursive state,
/// sort state, or root folder changes.
final gridItemsProvider = Provider<List<GridItem>>((ref) {
  final files = ref.watch(filteredSortedFileListProvider);
  final isRecursive = ref.watch(recursiveLoadingProvider);
  final sortState = ref.watch(sortStateProvider);
  final rootFolder = ref.watch(loadedFolderPathProvider);

  return buildGridItems(
    files: files,
    rootFolder: rootFolder,
    isRecursive: isRecursive,
    isSorted: sortState.isSorted,
  );
});

/// Builds the mixed list of grid items from a filtered/sorted file list.
///
/// When [isRecursive] is false or [isSorted] is true or [rootFolder] is null,
/// returns only [FileGridItem] wrappers with no separators.
///
/// When separators are shown, files are grouped by parent directory,
/// groups are ordered alphabetically by relative path (root first),
/// and files within each group are ordered by filename (case-insensitive).
List<GridItem> buildGridItems({
  required List<AudioFile> files,
  required String? rootFolder,
  required bool isRecursive,
  required bool isSorted,
}) {
  if (files.isEmpty) return [];

  // No separators when non-recursive, sorted, or no root folder.
  if (!isRecursive || isSorted || rootFolder == null) {
    return files
        .asMap()
        .entries
        .map((e) => FileGridItem(file: e.value, fileIndex: e.key))
        .toList();
  }

  final normalRoot = p.normalize(rootFolder);

  // Group files by parent directory, preserving original indices.
  final groups = <String, List<_IndexedFile>>{};
  for (var i = 0; i < files.length; i++) {
    final dirPath = p.dirname(files[i].path);
    final normalDir = p.normalize(dirPath);
    groups.putIfAbsent(normalDir, () => []).add(_IndexedFile(files[i], i));
  }

  // Sort groups alphabetically by relative path, root first.
  final sortedDirs = groups.keys.toList()
    ..sort((a, b) {
      final aIsRoot = a == normalRoot;
      final bIsRoot = b == normalRoot;
      if (aIsRoot && bIsRoot) return 0;
      if (aIsRoot) return -1;
      if (bIsRoot) return 1;

      final aRel = computeRelativePath(a, normalRoot);
      final bRel = computeRelativePath(b, normalRoot);
      return aRel.toLowerCase().compareTo(bRel.toLowerCase());
    });

  // Build the output list with separators and sorted files.
  final result = <GridItem>[];
  for (final dir in sortedDirs) {
    final relativePath = computeRelativePath(dir, normalRoot);
    result.add(SeparatorGridItem(relativePath: relativePath));

    // Sort files within the group by filename (case-insensitive).
    final groupFiles = groups[dir]!
      ..sort(
        (a, b) =>
            a.file.filename.toLowerCase().compareTo(
              b.file.filename.toLowerCase(),
            ),
      );

    for (final indexed in groupFiles) {
      result.add(FileGridItem(file: indexed.file, fileIndex: indexed.index));
    }
  }

  return result;
}

/// Internal helper to track a file with its original index.
class _IndexedFile {
  const _IndexedFile(this.file, this.index);
  final AudioFile file;
  final int index;
}
