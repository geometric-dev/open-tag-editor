import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/undo/undo_redo_manager.dart';
import '../../../shared/models/audio_file.dart';
import '../../../shared/services/tag_reader_service.dart';
import '../../tag_editor/data/providers/file_list_provider.dart';
import 'album_art_command.dart';
import 'models/batch_progress.dart';

/// Output format for converted cover art.
enum CoverArtFormat { keep, jpeg, png }

/// Options for a cover-art resize/convert batch.
class CoverArtResizeOptions {
  const CoverArtResizeOptions({
    required this.maxDimension,
    this.format = CoverArtFormat.keep,
    this.jpegQuality = 90,
  });

  /// Bounding box: art is scaled down so the longest side is at most this.
  final int maxDimension;

  /// Target encoding; [CoverArtFormat.keep] re-encodes in the source type
  /// (JPEG stays JPEG, PNG stays PNG, anything else becomes JPEG).
  final CoverArtFormat format;

  /// JPEG quality (1-100) when the output is JPEG.
  final int jpegQuality;
}

/// Result of resizing one file's embedded art.
class _ResizeOutcome {
  const _ResizeOutcome(this.path, this.newArt);
  final String path;
  final AlbumArtData newArt;
}

/// Resizes and/or converts embedded cover art across files.
///
/// Mirrors Tag&Rename's "Resize Files Cover Art" tool. Each file's current
/// art is decoded with the pure-Dart `image` package, scaled to fit
/// [CoverArtResizeOptions.maxDimension], re-encoded, and written through
/// [TagWriterService.writeAlbumArt]. A single undoable [AlbumArtCommand]
/// captures every previous image so Ctrl+Z restores all originals.
/// Files without embedded art are skipped.
class CoverArtResizeService {
  /// Creates a [CoverArtResizeService] with the given dependencies.
  CoverArtResizeService({
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

  /// Runs the resize/convert batch over [files].
  ///
  /// Yields [BatchProgress] events; per-file failures do not stop the batch.
  Stream<BatchProgress> resizeAlbumArt(
    List<AudioFile> files,
    CoverArtResizeOptions options,
  ) async* {
    final total = files.length;
    final failures = <BatchFailure>[];
    final outcomes = <_ResizeOutcome>[];
    var completed = 0;

    for (final file in files) {
      yield BatchProgress(
        completed: completed,
        total: total,
        failures: List.unmodifiable(failures),
        currentFile: file.path,
      );

      try {
        final art = file.albumArt;
        if (art == null) {
          completed++;
          continue; // Nothing embedded to resize — skip silently.
        }

        final resized = _transform(art, options);
        await tagWriter.writeAlbumArt(file.path, resized);
        outcomes.add(_ResizeOutcome(file.path, resized));
      } catch (e) {
        failures.add(BatchFailure(path: file.path, error: e.toString()));
      }
      completed++;
    }

    if (outcomes.isNotEmpty) {
      // In-memory refresh so previews show the resized images immediately.
      final updated = <AudioFile>[];
      for (final file in fileListNotifier.currentFiles) {
        final outcome = outcomes.where((o) => o.path == file.path).toList();
        if (outcome.isEmpty) continue;
        updated.add(
          file.copyWith(albumArt: outcome.first.newArt, isModified: true),
        );
      }
      if (updated.isNotEmpty) fileListNotifier.updateFiles(updated);

      undoRedoManager.execute(
        AlbumArtCommand(
          fileListNotifier: fileListNotifier,
          filePaths: [for (final o in outcomes) o.path],
          previousArtMap: {
            for (final f in files)
              if (outcomes.any((o) => o.path == f.path)) f.path: f.albumArt,
          },
          newArt: outcomes.first.newArt,
          operationType: AlbumArtOperationType.add,
        ),
      );
    }

    yield BatchProgress(
      completed: completed,
      total: total,
      failures: List.unmodifiable(failures),
    );
  }

  /// Decodes, downscales (never upscales), and re-encodes one image.
  static Uint8List transformBytes(Uint8List bytes, CoverArtResizeOptions opts) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unrecognized image data');
    }

    var work = decoded;
    final longest = work.width > work.height ? work.width : work.height;
    if (longest > opts.maxDimension) {
      work = img.copyResize(
        work,
        width: work.width >= work.height ? opts.maxDimension : null,
        height: work.height > work.width ? opts.maxDimension : null,
      );
    }

    final isPng = _looksLikePng(bytes);
    switch (opts.format) {
      case CoverArtFormat.png:
      case CoverArtFormat.keep when isPng:
        return Uint8List.fromList(img.encodePng(work));
      case CoverArtFormat.jpeg:
      case CoverArtFormat.keep:
        return Uint8List.fromList(
          img.encodeJpg(work, quality: opts.jpegQuality),
        );
    }
  }

  AlbumArtData _transform(AlbumArtData art, CoverArtResizeOptions opts) {
    final bytes = transformBytes(art.bytes, opts);
    final mimeType = switch (opts.format) {
      CoverArtFormat.png => 'image/png',
      CoverArtFormat.jpeg => 'image/jpeg',
      CoverArtFormat.keep =>
        art.mimeType.startsWith('image/png') ? 'image/png' : 'image/jpeg',
    };
    return AlbumArtData(
      bytes: bytes,
      mimeType: mimeType,
      description: art.description,
      type: art.type,
    );
  }

  static bool _looksLikePng(Uint8List bytes) =>
      bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}
