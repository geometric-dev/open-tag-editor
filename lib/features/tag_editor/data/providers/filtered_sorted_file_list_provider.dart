import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../shared/models/audio_file.dart';
import '../models/sort_state.dart';
import 'editor_state_provider.dart';
import 'file_list_provider.dart';
import 'selection_provider.dart';
import 'sort_state_provider.dart';

/// Toggle for showing only selected files.
final showSelectedOnlyProvider = StateProvider<bool>((ref) => false);

/// Provides the file list after applying text filter, selection filter, and sort.
final filteredSortedFileListProvider = Provider<List<AudioFile>>((ref) {
  var files = ref.watch(fileListProvider);

  // Apply text filter
  final filter = ref.watch(fileFilterProvider).toLowerCase();
  if (filter.isNotEmpty) {
    files = files.where((file) {
      return file.filename.toLowerCase().contains(filter) ||
          file.tags.values.any((v) => v.toLowerCase().contains(filter));
    }).toList();
  }

  // Apply "show selected only" filter
  final showSelectedOnly = ref.watch(showSelectedOnlyProvider);
  if (showSelectedOnly) {
    final selection = ref.watch(selectionProvider);
    final filtered = files
        .where((f) => selection.selectedPaths.contains(f.path))
        .toList();
    if (filtered.isEmpty && files.isNotEmpty) {
      // Auto-deactivate: would show zero files
      Future.microtask(() {
        ref.read(showSelectedOnlyProvider.notifier).state = false;
        ref.read(statusMessageProvider.notifier).state =
            'Filter cleared \u2014 no selected files to show';
      });
    } else {
      files = filtered;
    }
  }

  // Apply sort
  final sortState = ref.watch(sortStateProvider);
  if (sortState.isSorted) {
    files = _sortFiles(List.from(files), sortState);
  }

  return files;
});

/// Sorts files by the given sort state.
List<AudioFile> _sortFiles(List<AudioFile> files, SortState sortState) {
  final columnId = sortState.columnId!;

  files.sort((a, b) {
    final comparison = _compareByColumn(a, b, columnId);
    return sortState.direction == SortDirection.descending
        ? -comparison
        : comparison;
  });

  return files;
}

/// Compares two AudioFiles by the given column.
///
/// Uses numeric comparison for numeric columns, case-insensitive
/// string comparison for text columns.
int _compareByColumn(AudioFile a, AudioFile b, String columnId) {
  switch (columnId) {
    case 'filename':
      return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
    case 'duration':
      return (a.duration ?? 0).compareTo(b.duration ?? 0);
    case 'bitrate':
      return (a.bitrate ?? 0).compareTo(b.bitrate ?? 0);
    case 'trackNumber':
      return _numericCompare(
        a.tags['trackNumber'],
        b.tags['trackNumber'],
      );
    case 'discNumber':
      return _numericCompare(
        a.tags['discNumber'],
        b.tags['discNumber'],
      );
    case 'year':
      return _numericCompare(a.tags['year'], b.tags['year']);
    case 'bpm':
      return _numericCompare(a.tags['bpm'], b.tags['bpm']);
    default:
      // String comparison for tag fields
      final aVal = (a.tags[columnId] ?? '').toLowerCase();
      final bVal = (b.tags[columnId] ?? '').toLowerCase();
      return aVal.compareTo(bVal);
  }
}

/// Compares two nullable numeric strings numerically.
int _numericCompare(String? a, String? b) {
  final aNum = int.tryParse(a ?? '') ?? 0;
  final bNum = int.tryParse(b ?? '') ?? 0;
  return aNum.compareTo(bNum);
}
