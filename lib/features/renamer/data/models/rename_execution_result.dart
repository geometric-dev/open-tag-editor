/// Summary of a completed rename batch.
class RenameExecutionResult {
  const RenameExecutionResult({
    required this.renamedCount,
    required this.skippedCount,
    required this.errorCount,
    this.errors = const [],
  });

  /// Number of files successfully renamed.
  final int renamedCount;

  /// Number of files skipped (conflicts, unchanged).
  final int skippedCount;

  /// Number of files that encountered errors.
  final int errorCount;

  /// Details of each error encountered.
  final List<RenameError> errors;

  /// Total files processed.
  int get totalCount => renamedCount + skippedCount + errorCount;
}

/// Details of a single rename error.
class RenameError {
  const RenameError({
    required this.filePath,
    required this.message,
  });

  /// Path of the file that failed.
  final String filePath;

  /// Human-readable error message.
  final String message;
}
