import '../../features/tag_editor/data/providers/file_list_provider.dart';
import '../../shared/models/audio_file.dart';
import 'undo_redo_manager.dart';

/// Command for editing a single tag field on one or more files.
class TagEditCommand implements UndoableCommand {
  TagEditCommand({
    required this.fileListNotifier,
    required this.filePaths,
    required this.fieldName,
    required this.newValue,
    required this.previousValues,
  });

  final FileListNotifier fileListNotifier;
  final List<String> filePaths;
  final String fieldName;
  final String newValue;

  /// Map of file path -> previous value for that field.
  final Map<String, String?> previousValues;

  @override
  String get description {
    if (filePaths.length == 1) {
      return 'Edit $fieldName';
    }
    return 'Edit $fieldName (${filePaths.length} files)';
  }

  @override
  void execute() {
    final currentFiles = fileListNotifier.currentFiles;
    final updatedFiles = <AudioFile>[];

    for (final file in currentFiles) {
      if (filePaths.contains(file.path)) {
        final newTags = Map<String, String>.from(file.tags);
        if (newValue.isEmpty) {
          newTags.remove(fieldName);
        } else {
          newTags[fieldName] = newValue;
        }
        updatedFiles.add(file.copyWith(tags: newTags, isModified: true));
      }
    }

    fileListNotifier.updateFiles(updatedFiles);
  }

  @override
  void undo() {
    final currentFiles = fileListNotifier.currentFiles;
    final updatedFiles = <AudioFile>[];

    for (final file in currentFiles) {
      if (filePaths.contains(file.path)) {
        final newTags = Map<String, String>.from(file.tags);
        final previousValue = previousValues[file.path];
        if (previousValue == null || previousValue.isEmpty) {
          newTags.remove(fieldName);
        } else {
          newTags[fieldName] = previousValue;
        }
        updatedFiles.add(file.copyWith(tags: newTags, isModified: true));
      }
    }

    fileListNotifier.updateFiles(updatedFiles);
  }
}

/// Command for batch-editing multiple fields on multiple files.
class BatchTagEditCommand implements UndoableCommand {
  BatchTagEditCommand({
    required this.fileListNotifier,
    required this.filePaths,
    required this.newValues,
    required this.previousValues,
  });

  final FileListNotifier fileListNotifier;
  final List<String> filePaths;

  /// The new tag values to apply.
  final Map<String, String> newValues;

  /// Map of file path -> previous tag map.
  final Map<String, Map<String, String>> previousValues;

  @override
  String get description => 'Batch edit (${filePaths.length} files)';

  @override
  void execute() {
    final currentFiles = fileListNotifier.currentFiles;
    final updatedFiles = <AudioFile>[];

    for (final file in currentFiles) {
      if (filePaths.contains(file.path)) {
        final newTags = Map<String, String>.from(file.tags);
        for (final entry in newValues.entries) {
          if (entry.value.isEmpty) {
            newTags.remove(entry.key);
          } else {
            newTags[entry.key] = entry.value;
          }
        }
        updatedFiles.add(file.copyWith(tags: newTags, isModified: true));
      }
    }

    fileListNotifier.updateFiles(updatedFiles);
  }

  @override
  void undo() {
    final currentFiles = fileListNotifier.currentFiles;
    final updatedFiles = <AudioFile>[];

    for (final file in currentFiles) {
      if (filePaths.contains(file.path)) {
        final prevTags = previousValues[file.path] ?? {};
        updatedFiles.add(file.copyWith(
          tags: Map<String, String>.from(prevTags),
          isModified: true,
        ),);
      }
    }

    fileListNotifier.updateFiles(updatedFiles);
  }
}
