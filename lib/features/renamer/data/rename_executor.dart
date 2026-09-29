import 'dart:io';

import 'filename_sanitizer.dart';
import 'models/conflict_strategy.dart';
import 'models/rename_execution_result.dart';
import 'models/rename_plan.dart';

/// Validation result for a single rename plan.
class RenameValidationResult {
  /// Creates a [RenameValidationResult].
  const RenameValidationResult({
    required this.plan,
    required this.isValid,
    this.errors = const [],
  });

  /// The rename plan that was validated.
  final RenamePlan plan;

  /// Whether the plan passed validation.
  final bool isValid;

  /// Validation errors found, if any.
  final List<String> errors;
}

/// Executes rename operations on the filesystem.
class RenameExecutor {
  /// Creates a [RenameExecutor] with an optional [sanitizer].
  RenameExecutor({FilenameSanitizer? sanitizer})
    : _sanitizer = sanitizer ?? FilenameSanitizer();

  final FilenameSanitizer _sanitizer;

  /// Performs a dry-run validation without modifying files.
  ///
  /// Returns a [RenameValidationResult] for each plan indicating whether
  /// the rename would succeed.
  Future<List<RenameValidationResult>> dryRun(List<RenamePlan> plans) async {
    final results = <RenameValidationResult>[];

    for (final plan in plans) {
      final errors = <String>[];

      // Validate target path using sanitizer.
      final validationErrors = _sanitizer.validate(plan.targetPath);
      for (final error in validationErrors) {
        errors.add(error.message);
      }

      // Check if source file exists.
      final sourceFile = File(plan.sourcePath);
      if (!sourceFile.existsSync()) {
        errors.add('Source file does not exist: ${plan.sourcePath}');
      }

      results.add(
        RenameValidationResult(
          plan: plan,
          isValid: errors.isEmpty,
          errors: errors,
        ),
      );
    }

    return results;
  }

  /// Executes the rename batch with the given conflict resolution strategy.
  ///
  /// Returns a [RenameExecutionResult] summarizing the operation.
  Future<RenameExecutionResult> execute(
    List<RenamePlan> plans, {
    required ConflictStrategy strategy,
  }) async {
    var renamedCount = 0;
    var skippedCount = 0;
    var errorCount = 0;
    final errors = <RenameError>[];

    for (final plan in plans) {
      try {
        // Create target directory if it doesn't exist.
        final targetDir = File(plan.targetPath).parent;
        await Directory(targetDir.path).create(recursive: true);

        var targetPath = plan.targetPath;
        final targetFile = File(targetPath);

        if (targetFile.existsSync()) {
          switch (strategy) {
            case ConflictStrategy.skip:
              skippedCount++;
              continue;
            case ConflictStrategy.overwrite:
              await targetFile.delete();
            case ConflictStrategy.autoIncrement:
              targetPath = _findUniquePath(targetPath);
          }
        }

        // Attempt rename.
        await _renameFile(plan.sourcePath, targetPath);
        renamedCount++;
      } catch (e) {
        errorCount++;
        errors.add(
          RenameError(filePath: plan.sourcePath, message: e.toString()),
        );
      }
    }

    return RenameExecutionResult(
      renamedCount: renamedCount,
      skippedCount: skippedCount,
      errorCount: errorCount,
      errors: errors,
    );
  }

  /// Attempts to rename a file, falling back to copy-then-delete on failure.
  ///
  /// Karaoke companions: when a `.cdg` file shares the source's basename,
  /// it is renamed to match the target too (Tag&Rename behaviour). A
  /// companion that cannot be renamed is reported but does not fail the
  /// audio rename, which has already succeeded.
  Future<void> _renameFile(String sourcePath, String targetPath) async {
    try {
      await File(sourcePath).rename(targetPath);
    } catch (_) {
      // Fall back to copy-then-delete (handles cross-device moves).
      await File(sourcePath).copy(targetPath);
      await File(sourcePath).delete();
    }

    final companion = _cdgCompanion(sourcePath);
    if (companion == null) return;
    final companionTarget = _swapExtension(targetPath, '.cdg');
    try {
      await File(companion).rename(companionTarget);
    } catch (e) {
      throw Exception('Audio renamed but companion .cdg failed: $e');
    }
  }

  /// Returns the `.cdg` sibling for [audioPath] if one exists.
  String? _cdgCompanion(String audioPath) {
    final candidate = _swapExtension(audioPath, '.cdg');
    return File(candidate).existsSync() ? candidate : null;
  }

  /// Replaces the extension of [path], keeping the basename.
  static String _swapExtension(String path, String newExt) {
    final dot = path.lastIndexOf('.');
    final base = dot <= 0 ? path : path.substring(0, dot);
    return '$base$newExt';
  }

  /// Finds a unique path by appending ` (1)`, ` (2)`, etc.
  String _findUniquePath(String path) {
    final file = File(path);
    final parent = file.parent.path;
    final fullName = file.uri.pathSegments.last;

    final dotIndex = fullName.lastIndexOf('.');
    final baseName = dotIndex == -1
        ? fullName
        : fullName.substring(0, dotIndex);
    final extension = dotIndex == -1 ? '' : fullName.substring(dotIndex);

    var counter = 1;
    var candidate = path;
    while (File(candidate).existsSync()) {
      candidate =
          '$parent${Platform.pathSeparator}$baseName ($counter)$extension';
      counter++;
    }

    return candidate;
  }
}
