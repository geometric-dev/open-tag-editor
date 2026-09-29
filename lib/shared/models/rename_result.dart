/// Result of a rename operation.
class RenameResult {
  const RenameResult({
    required this.originalPath,
    required this.newPath,
    required this.success,
    this.error,
  });

  final String originalPath;
  final String newPath;
  final bool success;
  final String? error;
}

/// Exception thrown when a rename would overwrite an existing file.
class RenameConflictException implements Exception {
  const RenameConflictException(this.message, this.sourcePath, this.targetPath);

  final String message;
  final String sourcePath;
  final String targetPath;

  @override
  String toString() => 'RenameConflictException: $message';
}
