import '../models/audio_file.dart';

/// Abstract interface for reading audio file tags.
///
/// Implementations will use platform-specific libraries (e.g., FFI bindings
/// to TagLib, or a pure Dart implementation) to read metadata from audio files.
abstract class TagReaderService {
  /// Reads metadata from the audio file at [path].
  ///
  /// Returns an [AudioFile] populated with tag data and audio properties.
  /// Throws [TagReadException] if the file cannot be read.
  Future<AudioFile> readTags(String path);

  /// Reads metadata from multiple files.
  ///
  /// Returns a list of [AudioFile] objects. Files that fail to read
  /// will be included with empty tags and an error flag.
  Future<List<AudioFile>> readTagsBatch(List<String> paths);
}

/// Abstract interface for writing audio file tags.
abstract class TagWriterService {
  /// Writes the given [tags] to the audio file at [path].
  ///
  /// Only fields present in the map will be updated; others remain unchanged.
  /// Throws [TagWriteException] if the file cannot be written.
  Future<void> writeTags(String path, Map<String, String> tags);

  /// Writes album art to the audio file at [path].
  Future<void> writeAlbumArt(String path, AlbumArtData art);

  /// Removes all album art from the audio file at [path].
  Future<void> removeAlbumArt(String path);

  /// Writes tags to multiple files in batch.
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  );
}

/// Result of a tag write operation.
class TagWriteResult {
  const TagWriteResult({required this.path, required this.success, this.error});

  final String path;
  final bool success;
  final String? error;
}

/// Exception thrown when reading tags fails.
class TagReadException implements Exception {
  const TagReadException(this.message, this.path);

  final String message;
  final String path;

  @override
  String toString() => 'TagReadException: $message (file: $path)';
}

/// Exception thrown when writing tags fails.
class TagWriteException implements Exception {
  const TagWriteException(this.message, this.path);

  final String message;
  final String path;

  @override
  String toString() => 'TagWriteException: $message (file: $path)';
}
