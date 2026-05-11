import 'dart:async';
import 'dart:typed_data';

import '../../../core/undo/undo_redo_manager.dart';
import '../../../shared/models/audio_file.dart';
import '../../../shared/services/tag_reader_service.dart';
import '../../tag_editor/data/providers/file_list_provider.dart';
import 'album_art_command.dart';
import 'models/batch_progress.dart';

/// Coordinates album art add/remove operations with undo support,
/// batch progress tracking, and in-memory state updates.
class AlbumArtManager {
  /// Creates an [AlbumArtManager] with the given dependencies.
  AlbumArtManager({
    required this.tagWriter,
    required this.fileListNotifier,
    required this.undoRedoManager,
  });

  /// The tag writer service for disk operations.
  final TagWriterService tagWriter;

  /// The file list notifier for in-memory state updates.
  final FileListNotifier fileListNotifier;

  /// The undo/redo manager for registering undoable commands.
  final UndoRedoManager undoRedoManager;

  /// Adds album art to all specified files.
  ///
  /// Writes the image to each file on disk via [TagWriterService.writeAlbumArt],
  /// updates in-memory state, and registers a single undoable command.
  /// Returns a stream of [BatchProgress] events for UI feedback.
  ///
  /// Continues processing on per-file failures.
  Stream<BatchProgress> addAlbumArt({
    required List<AudioFile> files,
    required Uint8List imageBytes,
    required String mimeType,
  }) async* {
    final total = files.length;
    final failures = <BatchFailure>[];
    var completed = 0;

    final art = AlbumArtData(
      bytes: imageBytes,
      mimeType: mimeType,
      type: AlbumArtType.frontCover,
    );

    // Capture previous art state for undo
    final previousArtMap = <String, AlbumArtData?>{};
    for (final file in files) {
      previousArtMap[file.path] = file.albumArt;
    }

    final successPaths = <String>[];

    for (final file in files) {
      yield BatchProgress(
        completed: completed,
        total: total,
        failures: List.unmodifiable(failures),
        currentFile: file.path,
      );

      try {
        await tagWriter.writeAlbumArt(file.path, art);
        successPaths.add(file.path);
      } catch (e) {
        failures.add(BatchFailure(path: file.path, error: e.toString()));
      }

      completed++;
    }

    // Update in-memory state and register undo command for successful writes
    if (successPaths.isNotEmpty) {
      final command = AlbumArtCommand(
        fileListNotifier: fileListNotifier,
        filePaths: successPaths,
        previousArtMap: previousArtMap,
        newArt: art,
        operationType: AlbumArtOperationType.add,
      );
      undoRedoManager.execute(command);
    }

    yield BatchProgress(
      completed: completed,
      total: total,
      failures: List.unmodifiable(failures),
    );
  }

  /// Removes album art from all specified files.
  ///
  /// Calls [TagWriterService.removeAlbumArt] on each file, updates in-memory
  /// state, and registers a single undoable command.
  /// Returns a stream of [BatchProgress] events for UI feedback.
  ///
  /// Continues processing on per-file failures.
  Stream<BatchProgress> removeAlbumArt({
    required List<AudioFile> files,
  }) async* {
    final total = files.length;
    final failures = <BatchFailure>[];
    var completed = 0;

    // Capture previous art state for undo
    final previousArtMap = <String, AlbumArtData?>{};
    for (final file in files) {
      previousArtMap[file.path] = file.albumArt;
    }

    final successPaths = <String>[];

    for (final file in files) {
      yield BatchProgress(
        completed: completed,
        total: total,
        failures: List.unmodifiable(failures),
        currentFile: file.path,
      );

      try {
        await tagWriter.removeAlbumArt(file.path);
        successPaths.add(file.path);
      } catch (e) {
        failures.add(BatchFailure(path: file.path, error: e.toString()));
      }

      completed++;
    }

    // Update in-memory state and register undo command for successful removals
    if (successPaths.isNotEmpty) {
      final command = AlbumArtCommand(
        fileListNotifier: fileListNotifier,
        filePaths: successPaths,
        previousArtMap: previousArtMap,
        newArt: null,
        operationType: AlbumArtOperationType.remove,
      );
      undoRedoManager.execute(command);
    }

    yield BatchProgress(
      completed: completed,
      total: total,
      failures: List.unmodifiable(failures),
    );
  }
}
