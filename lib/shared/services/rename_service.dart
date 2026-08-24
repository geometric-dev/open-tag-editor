import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/file_utils.dart';
import '../models/audio_file.dart';
import '../models/rename_pattern.dart';

/// Service for renaming audio files based on tag data and patterns.
class RenameService {
  /// Generates a preview of what the file would be renamed to.
  ///
  /// Returns the new filename (with extension) without actually renaming.
  String preview(AudioFile file, RenamePattern pattern) {
    final newName = pattern.apply(file.tags);
    final sanitized = FileUtils.sanitizeFilename(newName);
    return '$sanitized${file.extension}';
  }

  /// Generates rename previews for multiple files.
  Map<String, String> previewBatch(
    List<AudioFile> files,
    RenamePattern pattern,
  ) {
    final results = <String, String>{};
    for (final file in files) {
      results[file.path] = preview(file, pattern);
    }
    return results;
  }

  /// Renames a single file based on the pattern.
  ///
  /// Returns the new file path, or throws if the rename fails.
  Future<String> rename(AudioFile file, RenamePattern pattern) async {
    final newName = preview(file, pattern);
    final directory = p.dirname(file.path);

    // Handle subdirectory creation from patterns like "%artist%/%title%"
    final newRelativePath = pattern.apply(file.tags);
    final parts = newRelativePath.split('/');

    String targetDir;
    String targetFilename;

    if (parts.length > 1) {
      // Pattern includes directory separators
      targetDir = p.joinAll([directory, ...parts.sublist(0, parts.length - 1)]);
      targetFilename =
          '${FileUtils.sanitizeFilename(parts.last)}${file.extension}';
    } else {
      targetDir = directory;
      targetFilename = newName;
    }

    // Create target directory if needed
    final dir = Directory(targetDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final targetPath = p.join(targetDir, targetFilename);

    // Don't rename if the path hasn't changed
    if (targetPath == file.path) return file.path;

    // Check for conflicts
    if (File(targetPath).existsSync()) {
      throw RenameConflictException(
        'Target file already exists: $targetPath',
        file.path,
        targetPath,
      );
    }

    await File(file.path).rename(targetPath);
    return targetPath;
  }

  /// Renames multiple files. Returns results for each file.
  Future<List<RenameResult>> renameBatch(
    List<AudioFile> files,
    RenamePattern pattern,
  ) async {
    final results = <RenameResult>[];
    for (final file in files) {
      try {
        final newPath = await rename(file, pattern);
        results.add(
          RenameResult(
            originalPath: file.path,
            newPath: newPath,
            success: true,
          ),
        );
      } on Exception catch (e) {
        results.add(
          RenameResult(
            originalPath: file.path,
            newPath: file.path,
            success: false,
            error: e.toString(),
          ),
        );
      }
    }
    return results;
  }
}

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
