import '../../models/audio_file.dart';
import '../tag_reader_service.dart';

/// A [TagWriterService] that refuses all write operations.
///
/// Used as a fallback when the native TagLib library cannot be loaded,
/// ensuring the unsafe pure-Dart writer is never used.
class DisabledWriterService implements TagWriterService {
  @override
  Future<void> writeTags(String path, Map<String, String> tags) =>
      throw TagWriteException(
        'Native TagLib library not available. Writing is disabled.',
        path,
      );

  @override
  Future<void> writeAlbumArt(String path, AlbumArtData art) =>
      throw TagWriteException(
        'Native TagLib library not available. Writing is disabled.',
        path,
      );

  @override
  Future<void> removeAlbumArt(String path) => throw TagWriteException(
    'Native TagLib library not available. Writing is disabled.',
    path,
  );

  @override
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  ) async => fileTagsMap.keys
      .map(
        (p) => TagWriteResult(
          path: p,
          success: false,
          error: 'Native TagLib library not available.',
        ),
      )
      .toList();
}
