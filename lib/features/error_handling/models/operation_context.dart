/// Captures the exact parameters needed to retry a failed operation.
sealed class OperationContext {
  const OperationContext();
}

/// Context for retrying a failed tag read.
class ReadOperationContext extends OperationContext {
  const ReadOperationContext({required this.filePath});

  /// Path to the file that failed to read.
  final String filePath;
}

/// Context for retrying a failed tag write.
class WriteOperationContext extends OperationContext {
  const WriteOperationContext({
    required this.filePath,
    required this.tags,
  });

  /// Path to the file that failed to write.
  final String filePath;

  /// The tag data that was being written.
  final Map<String, String> tags;
}

/// Context for retrying a failed file rename.
class RenameOperationContext extends OperationContext {
  const RenameOperationContext({
    required this.filePath,
    required this.targetPath,
  });

  /// Original path of the file.
  final String filePath;

  /// The intended target path for the rename.
  final String targetPath;
}
