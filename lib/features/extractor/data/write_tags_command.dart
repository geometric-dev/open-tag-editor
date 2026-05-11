import '../../../core/undo/undo_redo_manager.dart';
import '../../../shared/models/audio_file.dart';
import '../../tag_editor/data/providers/file_list_provider.dart';
import 'models/write_execution_result.dart';
import 'models/write_mode.dart';

/// Undoable command that writes extracted tag values to audio files.
///
/// Stores previous tag values for each modified file so the operation can
/// be fully reversed via [undo].
class WriteTagsCommand implements UndoableCommand {
  WriteTagsCommand({
    required this.fileListNotifier,
    required this.filePaths,
    required this.extractedValues,
    required this.previousValues,
    required this.writeMode,
  });

  /// The file list notifier for updating in-memory file state.
  final FileListNotifier fileListNotifier;

  /// Ordered list of file paths to write to.
  final List<String> filePaths;

  /// Map of file path → extracted tag values to write.
  final Map<String, Map<String, String>> extractedValues;

  /// Map of file path → previous tag map (for undo).
  final Map<String, Map<String, String>> previousValues;

  /// Controls whether to overwrite existing tags or only fill empty fields.
  final WriteMode writeMode;

  @override
  String get description {
    if (filePaths.length == 1) {
      return 'Tags from filename (1 file)';
    }
    return 'Tags from filename (${filePaths.length} files)';
  }

  @override
  void execute() {
    final currentFiles = fileListNotifier.currentFiles;
    final updatedFiles = <AudioFile>[];

    for (final file in currentFiles) {
      if (!filePaths.contains(file.path)) continue;

      final extracted = extractedValues[file.path];
      if (extracted == null || extracted.isEmpty) continue;

      final newTags = Map<String, String>.from(file.tags);

      for (final entry in extracted.entries) {
        switch (writeMode) {
          case WriteMode.overwriteExisting:
            if (entry.value.isNotEmpty) {
              newTags[entry.key] = entry.value;
            }
          case WriteMode.fillEmptyOnly:
            final existing = newTags[entry.key];
            if ((existing == null || existing.isEmpty) &&
                entry.value.isNotEmpty) {
              newTags[entry.key] = entry.value;
            }
        }
      }

      updatedFiles.add(file.copyWith(tags: newTags, isModified: true));
    }

    if (updatedFiles.isNotEmpty) {
      fileListNotifier.updateFiles(updatedFiles);
    }
  }

  @override
  void undo() {
    final currentFiles = fileListNotifier.currentFiles;
    final updatedFiles = <AudioFile>[];

    for (final file in currentFiles) {
      if (!filePaths.contains(file.path)) continue;

      final prevTags = previousValues[file.path];
      if (prevTags == null) continue;

      updatedFiles.add(
        file.copyWith(
          tags: Map<String, String>.from(prevTags),
          isModified: true,
        ),
      );
    }

    if (updatedFiles.isNotEmpty) {
      fileListNotifier.updateFiles(updatedFiles);
    }
  }

  /// Executes the write and returns a summary result.
  WriteExecutionResult executeWithResult() {
    final currentFiles = fileListNotifier.currentFiles;
    final currentFileMap = {for (final f in currentFiles) f.path: f};

    var writtenCount = 0;
    var skippedCount = 0;
    final errors = <WriteError>[];

    final updatedFiles = <AudioFile>[];

    for (final filePath in filePaths) {
      final file = currentFileMap[filePath];
      if (file == null) {
        skippedCount++;
        continue;
      }

      final extracted = extractedValues[filePath];
      if (extracted == null || extracted.isEmpty) {
        skippedCount++;
        continue;
      }

      try {
        final newTags = Map<String, String>.from(file.tags);

        for (final entry in extracted.entries) {
          switch (writeMode) {
            case WriteMode.overwriteExisting:
              if (entry.value.isNotEmpty) {
                newTags[entry.key] = entry.value;
              }
            case WriteMode.fillEmptyOnly:
              final existing = newTags[entry.key];
              if ((existing == null || existing.isEmpty) &&
                  entry.value.isNotEmpty) {
                newTags[entry.key] = entry.value;
              }
          }
        }

        updatedFiles.add(file.copyWith(tags: newTags, isModified: true));
        writtenCount++;
      } catch (e) {
        errors.add(WriteError(filePath: filePath, message: e.toString()));
      }
    }

    if (updatedFiles.isNotEmpty) {
      fileListNotifier.updateFiles(updatedFiles);
    }

    return WriteExecutionResult(
      writtenCount: writtenCount,
      skippedCount: skippedCount,
      errorCount: errors.length,
      errors: errors,
    );
  }
}
