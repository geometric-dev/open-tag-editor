import 'dart:io';

import '../../../core/undo/undo_redo_manager.dart';

/// Undoable command that reverses a batch rename operation.
class RenameCommand implements UndoableCommand {
  /// Creates a [RenameCommand] with the given [renames] map.
  RenameCommand({required this.renames});

  /// Map of original path → new path for each renamed file.
  final Map<String, String> renames;

  @override
  String get description {
    final count = renames.length;
    return count == 1 ? 'Rename file' : 'Rename $count files';
  }

  @override
  void execute() {
    for (final entry in renames.entries) {
      try {
        final file = File(entry.key);
        if (file.existsSync()) {
          final targetDir = Directory(entry.value).parent;
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
          file.renameSync(entry.value);
        }
      } catch (_) {
        // Graceful failure — file may have been moved externally.
      }
    }
  }

  @override
  void undo() {
    for (final entry in renames.entries) {
      try {
        final file = File(entry.value);
        if (file.existsSync()) {
          final targetDir = Directory(entry.key).parent;
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
          file.renameSync(entry.key);
        }
      } catch (_) {
        // Graceful failure — file may have been moved externally.
      }
    }
  }
}
