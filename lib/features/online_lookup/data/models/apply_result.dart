/// Result of applying metadata from online lookup to audio files.
class ApplyResult {
  const ApplyResult({
    required this.successCount,
    required this.failureCount,
    required this.fileResults,
  });

  /// Number of files successfully updated.
  final int successCount;

  /// Number of files that failed to update.
  final int failureCount;

  /// Per-file results.
  final List<ApplyFileResult> fileResults;
}

/// Result of applying metadata to a single file.
class ApplyFileResult {
  const ApplyFileResult({
    required this.path,
    required this.success,
    this.error,
  });

  /// Path to the file.
  final String path;

  /// Whether the write succeeded.
  final bool success;

  /// Error message if the write failed.
  final String? error;
}
