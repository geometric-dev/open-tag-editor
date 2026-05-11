/// Types used by the TagLib FFI integration layer.
library;

/// Represents the tag format detected in an audio file.
enum TagFormat {
  /// ID3v1 tags (MP3, limited to 128 bytes).
  id3v1,

  /// ID3v2.3 tags (MP3, most common).
  id3v2_3,

  /// ID3v2.4 tags (MP3, latest version).
  id3v2_4,

  /// Vorbis Comment (FLAC, OGG, Opus).
  vorbisComment,

  /// APE tags (APE, sometimes MP3/WavPack).
  apeTag,

  /// ASF metadata (WMA).
  asf,

  /// MP4/iTunes atom metadata (M4A, MP4, AAC).
  mp4Atoms,

  /// Tag format could not be determined.
  unknown,
}

/// Exception thrown when the native TagLib library cannot be loaded.
class NativeLibraryException implements Exception {
  /// Creates a [NativeLibraryException] with details about the failure.
  const NativeLibraryException(this.message, this.platform, this.attemptedPath);

  /// Description of what went wrong.
  final String message;

  /// The platform where loading was attempted (e.g., 'windows', 'macos', 'linux').
  final String platform;

  /// The file path that was attempted for loading.
  final String attemptedPath;

  @override
  String toString() =>
      'NativeLibraryException: $message (platform: $platform, path: $attemptedPath)';
}
