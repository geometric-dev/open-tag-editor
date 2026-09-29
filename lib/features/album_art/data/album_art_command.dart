import '../../../core/undo/undo_redo_manager.dart';
import '../../../features/tag_editor/data/providers/file_list_provider.dart';
import '../../../shared/models/audio_file.dart';

/// The type of album art operation.
enum AlbumArtOperationType { add, remove }

/// Undoable command for album art add/remove operations.
///
/// Stores the previous album art state for each affected file to enable
/// full reversal. A single command covers all files in a batch operation.
class AlbumArtCommand implements UndoableCommand {
  /// Creates an album art command.
  AlbumArtCommand({
    required this.fileListNotifier,
    required this.filePaths,
    required this.previousArtMap,
    required this.newArt,
    required this.operationType,
  });

  /// The file list notifier to update state through.
  final FileListNotifier fileListNotifier;

  /// Paths of all files affected by this operation.
  final List<String> filePaths;

  /// Map of file path → previous AlbumArtData (null if file had no art).
  final Map<String, AlbumArtData?> previousArtMap;

  /// The new art applied (null for remove operations).
  final AlbumArtData? newArt;

  /// Whether this was an add or remove operation.
  final AlbumArtOperationType operationType;

  @override
  String get description {
    final action = operationType == AlbumArtOperationType.add
        ? 'Add album art'
        : 'Remove album art';
    if (filePaths.length == 1) return action;
    return '$action (${filePaths.length} files)';
  }

  @override
  void execute() {
    final currentFiles = fileListNotifier.currentFiles;
    final updatedFiles = <AudioFile>[];

    for (final file in currentFiles) {
      if (filePaths.contains(file.path)) {
        if (newArt != null) {
          // Add operation
          updatedFiles.add(file.copyWith(albumArt: newArt, isModified: true));
        } else {
          // Remove operation
          updatedFiles.add(
            file.copyWith(clearAlbumArt: true, isModified: true),
          );
        }
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
        final previousArt = previousArtMap[file.path];
        if (previousArt != null) {
          updatedFiles.add(
            file.copyWith(albumArt: previousArt, isModified: true),
          );
        } else {
          updatedFiles.add(
            file.copyWith(clearAlbumArt: true, isModified: true),
          );
        }
      }
    }

    fileListNotifier.updateFiles(updatedFiles);
  }
}
