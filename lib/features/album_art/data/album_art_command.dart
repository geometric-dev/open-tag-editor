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
    this.newArt,
    this.newArtByPath,
    required this.operationType,
  });

  /// The file list notifier to update state through.
  final FileListNotifier fileListNotifier;

  /// Paths of all files affected by this operation.
  final List<String> filePaths;

  /// Map of file path → previous AlbumArtData (null if file had no art).
  final Map<String, AlbumArtData?> previousArtMap;

  /// The new art applied to *every* file (null for remove operations).
  ///
  /// Correct for "add this image to these files" and "remove art from these
  /// files", where each file genuinely ends up with the same image.
  final AlbumArtData? newArt;

  /// The new art applied to each file *individually*.
  ///
  /// Required when every file gets a different image, which is what a resize
  /// or convert of a batch of distinct covers produces. Passing only [newArt]
  /// there would paint the first file's cover over all the others.
  final Map<String, AlbumArtData>? newArtByPath;

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
  bool execute() {
    final updatedFiles = <AudioFile>[];

    for (final file in fileListNotifier.currentFiles) {
      if (!filePaths.contains(file.path)) continue;

      // Art is not a tag field, so it is not part of AudioFile.modifiedTags
      // and must not mark the file dirty: the write already happened, and
      // marking it dirty would leave the app permanently "unsaved" with a
      // Save button that can never do anything.
      final perFile = newArtByPath?[file.path];
      if (perFile != null) {
        updatedFiles.add(file.copyWith(albumArt: perFile));
      } else if (newArt != null) {
        updatedFiles.add(file.copyWith(albumArt: newArt));
      } else {
        updatedFiles.add(file.copyWith(clearAlbumArt: true));
      }
    }

    fileListNotifier.updateFiles(updatedFiles);
    return updatedFiles.isNotEmpty;
  }

  @override
  void undo() {
    final updatedFiles = <AudioFile>[];

    for (final file in fileListNotifier.currentFiles) {
      if (!filePaths.contains(file.path)) continue;

      final previousArt = previousArtMap[file.path];
      if (previousArt != null) {
        updatedFiles.add(file.copyWith(albumArt: previousArt));
      } else {
        updatedFiles.add(file.copyWith(clearAlbumArt: true));
      }
    }

    fileListNotifier.updateFiles(updatedFiles);
  }
}
