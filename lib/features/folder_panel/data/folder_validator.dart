import 'dart:io';

/// Validation error reasons for folder paths.
enum FolderValidationError {
  /// The path does not exist on the filesystem.
  notFound,

  /// The path exists but is not a directory.
  notADirectory,

  /// The path exists and is a directory but cannot be read.
  permissionDenied,
}

/// Result of validating a folder path.
class FolderValidationResult {
  /// Creates a successful validation result.
  const FolderValidationResult.ok() : error = null;

  /// Creates a failed validation result with the given [error].
  const FolderValidationResult.failed(this.error);

  /// The validation error, or null if validation succeeded.
  final FolderValidationError? error;

  /// Whether the path is valid and accessible.
  bool get isValid => error == null;
}

/// Validates folder paths before loading.
class FolderValidator {
  /// Checks if [path] exists and is readable.
  ///
  /// Returns a [FolderValidationResult] indicating success or the
  /// specific failure reason.
  Future<FolderValidationResult> validate(String path) async {
    final type = FileSystemEntity.typeSync(path);

    if (type == FileSystemEntityType.notFound) {
      return const FolderValidationResult.failed(
        FolderValidationError.notFound,
      );
    }

    if (type != FileSystemEntityType.directory) {
      return const FolderValidationResult.failed(
        FolderValidationError.notADirectory,
      );
    }

    // Check read permission by attempting to list the directory.
    try {
      Directory(path).listSync();
    } on FileSystemException {
      return const FolderValidationResult.failed(
        FolderValidationError.permissionDenied,
      );
    }

    return const FolderValidationResult.ok();
  }
}
