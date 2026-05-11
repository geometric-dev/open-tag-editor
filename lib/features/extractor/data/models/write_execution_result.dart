/// Summary of a completed tag-write batch.
class WriteExecutionResult {
  const WriteExecutionResult({
    required this.writtenCount,
    required this.skippedCount,
    required this.errorCount,
    this.errors = const [],
  });

  /// Number of files successfully written.
  final int writtenCount;

  /// Number of files skipped (non-matching or deselected).
  final int skippedCount;

  /// Number of files that encountered errors.
  final int errorCount;

  /// Details of individual file errors.
  final List<WriteError> errors;
}

/// Error details for a single file write failure.
class WriteError {
  const WriteError({required this.filePath, required this.message});

  /// Path of the file that failed.
  final String filePath;

  /// Error message describing the failure.
  final String message;
}
