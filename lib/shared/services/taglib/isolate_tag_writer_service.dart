import 'dart:isolate';

import '../../models/audio_file.dart';
import '../tag_reader_service.dart';
import 'isolate_tag_io.dart';
import 'native_library_loader.dart';
import 'taglib_writer_service.dart';

/// A [TagWriterService] that keeps the UI isolate responsive.
///
/// - Single-file operations (including album art) run directly on the
///   current isolate via a lazily-created native writer, preserving live
///   settings callbacks for interactive edits.
/// - [writeTagsBatch] (the bulk save path) resolves its settings into a
///   sendable snapshot, then performs all writes — atomic rename, optional
///   backup, post-write validation — inside a background isolate via
///   [Isolate.run]. Per-file failures are returned as failed
///   [TagWriteResult]s exactly as before; callers cannot tell the
///   difference.
class IsolateTagWriterService implements TagWriterService {
  IsolateTagWriterService({
    required TagWriteSettingsSnapshot Function() getSnapshot,
    required TagLibWriterService Function() createDirectWriter,
  }) : _getSnapshot = getSnapshot,
       _createDirectWriter = createDirectWriter;

  final TagWriteSettingsSnapshot Function() _getSnapshot;
  final TagLibWriterService Function() _createDirectWriter;

  /// Lazily-created same-isolate writer for single-file operations.
  TagLibWriterService? _direct;

  TagLibWriterService get _directWriter => _direct ??= _createDirectWriter();

  @override
  Future<void> writeTags(String path, Map<String, String> tags) =>
      _directWriter.writeTags(path, tags);

  @override
  Future<void> writeAlbumArt(String path, AlbumArtData art) =>
      _directWriter.writeAlbumArt(path, art);

  @override
  Future<void> removeAlbumArt(String path) =>
      _directWriter.removeAlbumArt(path);

  @override
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  ) async {
    if (fileTagsMap.isEmpty) return const [];

    // Resolve settings NOW, as plain values, on this isolate.
    final snapshot = _getSnapshot();
    final paths = Map.of(fileTagsMap);

    if (!NativeLibraryLoader.isAvailable) {
      return [
        for (final path in paths.keys)
          TagWriteResult(
            path: path,
            success: false,
            error: 'Native TagLib library not available.',
          ),
      ];
    }

    final results = await Isolate.run(() async {
      final writer = createNativeTagWriterFromSnapshot(snapshot);
      if (writer == null) {
        return [
          for (final path in paths.keys)
            TagWriteResult(
              path: path,
              success: false,
              error: 'Native TagLib library not available.',
            ),
        ];
      }
      return writer.writeTagsBatch(paths);
    });
    return List.unmodifiable(results);
  }
}
