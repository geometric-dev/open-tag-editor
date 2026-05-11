/// Progress event emitted during batch album art operations.
class BatchProgress {
  const BatchProgress({
    required this.completed,
    required this.total,
    required this.failures,
    this.currentFile,
  });

  /// Number of files processed so far.
  final int completed;

  /// Total number of files in the batch.
  final int total;

  /// List of files that failed during the operation.
  final List<BatchFailure> failures;

  /// Path of the file currently being processed.
  final String? currentFile;

  /// Whether all files have been processed.
  bool get isComplete => completed == total;

  /// Whether any files failed during the operation.
  bool get hasFailures => failures.isNotEmpty;

  /// Number of files that succeeded.
  int get successes => completed - failures.length;
}

/// Represents a single file failure during a batch operation.
class BatchFailure {
  const BatchFailure({required this.path, required this.error});

  /// Path of the file that failed.
  final String path;

  /// Error message describing the failure.
  final String error;
}
