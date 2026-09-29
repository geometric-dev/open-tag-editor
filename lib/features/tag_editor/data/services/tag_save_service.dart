import '../../../../shared/services/tag_reader_service.dart';
import '../providers/file_list_provider.dart';

/// Summary of a batch save of modified files.
class TagSaveSummary {
  const TagSaveSummary({required this.attemptedTags, required this.results});

  /// The tags that were written per file path (only changed fields).
  final Map<String, Map<String, String>> attemptedTags;

  /// Per-file write results.
  final List<TagWriteResult> results;

  int get successCount => results.where((r) => r.success).length;

  int get failureCount => results.where((r) => !r.success).length;

  bool get allSuccess => failureCount == 0;
}

/// Saves all modified files in one batch operation.
///
/// Single source of truth for the save flow so every entry point
/// (toolbar button, Ctrl+S, tag panel save, unsaved-changes guard)
/// behaves identically: only changed fields are written, successful
/// files are marked clean with refreshed originals, and failures are
/// reported in the returned [TagSaveSummary] for callers to surface
/// (status bar / snackbar / error log).
class TagSaveService {
  TagSaveService({
    required TagWriterService writer,
    required FileListNotifier fileListNotifier,
  }) : _writer = writer,
       _fileListNotifier = fileListNotifier;

  final TagWriterService _writer;
  final FileListNotifier _fileListNotifier;

  /// Saves every modified file currently loaded.
  ///
  /// Returns `null` when there is nothing to do (no modified files or
  /// no actual field changes), otherwise a summary of the write results.
  /// Files that wrote successfully are updated in the file list with
  /// `isModified: false` and refreshed original tags; failed files are
  /// left untouched (still dirty).
  Future<TagSaveSummary?> saveAllModified() async {
    final modifiedFiles = _fileListNotifier.currentFiles
        .where((f) => f.isModified)
        .toList();
    if (modifiedFiles.isEmpty) return null;

    final fileTagsMap = <String, Map<String, String>>{};
    for (final file in modifiedFiles) {
      final changed = file.modifiedTags;
      if (changed.isNotEmpty) {
        fileTagsMap[file.path] = changed;
      }
    }
    if (fileTagsMap.isEmpty) return null;

    final results = await _writer.writeTagsBatch(fileTagsMap);

    // Mark successful files as no longer modified.
    final updatedFiles = modifiedFiles
        .where((f) => results.any((r) => r.path == f.path && r.success))
        .map(
          (f) => f.copyWith(
            isModified: false,
            originalTags: Map<String, String>.unmodifiable(f.tags),
          ),
        )
        .toList();
    if (updatedFiles.isNotEmpty) {
      _fileListNotifier.updateFiles(updatedFiles);
    }

    return TagSaveSummary(attemptedTags: fileTagsMap, results: results);
  }
}
