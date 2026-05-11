/// Status of a single file in the rename preview.
enum RenamePreviewStatus {
  /// Rename will proceed normally.
  ok,

  /// Target path conflicts with another file.
  conflict,

  /// Mask produced an invalid or empty filename.
  error,

  /// File would not change (source == target).
  unchanged,
}

/// Preview of a single file rename operation.
class RenamePreview {
  const RenamePreview({
    required this.originalPath,
    required this.originalFilename,
    required this.newPath,
    required this.newFilename,
    required this.status,
    this.errorMessage,
  });

  /// Full original path of the file.
  final String originalPath;

  /// Original filename (without directory).
  final String originalFilename;

  /// Computed new full path.
  final String newPath;

  /// Computed new filename (without directory).
  final String newFilename;

  /// Status of this preview entry.
  final RenamePreviewStatus status;

  /// Error or warning message, if applicable.
  final String? errorMessage;
}
