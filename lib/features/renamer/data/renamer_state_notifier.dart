import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../../../core/undo/undo_redo_manager.dart';
import '../../../shared/models/audio_file.dart';
import 'case_transformer.dart';
import 'conflict_detector.dart';
import 'filename_sanitizer.dart';
import 'mask_evaluator.dart';
import 'mask_parser.dart';
import 'models/case_option.dart';
import 'models/conflict_strategy.dart';
import 'models/mask_parse_exception.dart';
import 'models/rename_execution_result.dart';
import 'models/rename_plan.dart';
import 'models/rename_preview.dart';
import 'models/renamer_state.dart';
import 'rename_command.dart';
import 'rename_executor.dart';

/// Manages rename dialog state including pattern, options, and previews.
class RenamerStateNotifier extends StateNotifier<RenamerState> {
  RenamerStateNotifier({
    required this.files,
    required this.undoRedoManager,
    MaskParser? parser,
    MaskEvaluator? evaluator,
    CaseTransformer? caseTransformer,
    FilenameSanitizer? sanitizer,
    ConflictDetector? conflictDetector,
    RenameExecutor? executor,
  })  : _parser = parser ?? MaskParser(),
        _evaluator = evaluator ?? MaskEvaluator(),
        _caseTransformer = caseTransformer ?? const CaseTransformer(),
        _sanitizer = sanitizer ?? FilenameSanitizer(),
        _conflictDetector = conflictDetector ?? const ConflictDetector(),
        _executor = executor ?? RenameExecutor(),
        super(const RenamerState());

  /// The list of audio files to rename.
  final List<AudioFile> files;

  /// The undo/redo manager for registering rename commands.
  final UndoRedoManager undoRedoManager;

  final MaskParser _parser;
  final MaskEvaluator _evaluator;
  final CaseTransformer _caseTransformer;
  final FilenameSanitizer _sanitizer;
  final ConflictDetector _conflictDetector;
  final RenameExecutor _executor;

  /// Updates the mask pattern and regenerates previews.
  void setPattern(String pattern) {
    try {
      final tokens = _parser.parse(pattern);
      state = state.copyWith(
        pattern: pattern,
        tokens: tokens,
        parseError: null,
      );
    } on MaskParseException catch (e) {
      state = state.copyWith(
        pattern: pattern,
        tokens: const [],
        parseError: e.message,
      );
    }
    _regeneratePreviews();
  }

  /// Updates the case transformation option and regenerates previews.
  void setCaseOption(CaseOption option) {
    state = state.copyWith(caseOption: option);
    _regeneratePreviews();
  }

  /// Toggles the "replace underscores" option and regenerates previews.
  void setReplaceUnderscores(bool value) {
    state = state.copyWith(replaceUnderscores: value);
    _regeneratePreviews();
  }

  /// Sets the conflict resolution strategy.
  void setConflictStrategy(ConflictStrategy strategy) {
    state = state.copyWith(conflictStrategy: strategy);
  }

  /// Executes the rename operation.
  ///
  /// Only files with [RenamePreviewStatus.ok] status are included in the
  /// execution plan.
  Future<RenameExecutionResult> executeRename() async {
    state = state.copyWith(isExecuting: true);

    try {
      final plans = state.previews
          .where((p) => p.status == RenamePreviewStatus.ok)
          .map((p) {
        final audioFile = files.firstWhere((f) => f.path == p.originalPath);
        return RenamePlan(
          sourcePath: p.originalPath,
          targetPath: p.newPath,
          audioFile: audioFile,
        );
      }).toList();

      final result = await _executor.execute(
        plans,
        strategy: state.conflictStrategy,
      );

      // Build the renames map for the undo command from successful renames.
      final renames = <String, String>{};
      for (final plan in plans) {
        // Only include plans that were actually renamed (not skipped/errored).
        final wasError = result.errors.any((e) => e.filePath == plan.sourcePath);
        if (!wasError) {
          renames[plan.sourcePath] = plan.targetPath;
        }
      }

      // Register undo command if any files were renamed.
      if (renames.isNotEmpty) {
        final command = RenameCommand(renames: renames);
        undoRedoManager.execute(command);
      }

      state = state.copyWith(
        isExecuting: false,
        executionResult: result,
      );

      return result;
    } catch (e) {
      final result = RenameExecutionResult(
        renamedCount: 0,
        skippedCount: 0,
        errorCount: files.length,
        errors: [
          RenameError(
            filePath: '',
            message: e.toString(),
          ),
        ],
      );

      state = state.copyWith(
        isExecuting: false,
        executionResult: result,
      );

      return result;
    }
  }

  /// Regenerates previews for all files based on current state.
  void _regeneratePreviews() {
    if (state.tokens.isEmpty || state.parseError != null) {
      state = state.copyWith(
        previews: const [],
        conflicts: const {},
      );
      return;
    }

    final previews = <RenamePreview>[];
    final previewsMap = <String, String>{};

    for (final file in files) {
      // Evaluate tokens against the file.
      final rawResult = _evaluator.evaluate(state.tokens, file);

      // Apply case transformation.
      final cased = _caseTransformer.transform(
        rawResult,
        option: state.caseOption,
        replaceUnderscores: state.replaceUnderscores,
      );

      // Split on directory separators, sanitize each segment individually,
      // then reassemble. This preserves intentional path structure from the
      // mask while sanitizing illegal characters within each segment.
      final isAbsolute = _isAbsolutePath(cased);
      final separatorPattern = RegExp(r'[/\\]');
      final segments = cased.split(separatorPattern);

      // Sanitize each segment, but skip the drive letter (e.g. "C:") on
      // Windows absolute paths since the colon is valid there. Also preserve
      // navigation segments ("." and "..") as-is.
      final sanitizedSegments = <String>[];
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        if (segment == '.' || segment == '..') {
          sanitizedSegments.add(segment);
        } else if (i == 0 && isAbsolute && Platform.isWindows) {
          // Preserve drive letter as-is (e.g. "C:")
          sanitizedSegments.add(segment);
        } else {
          sanitizedSegments.add(_sanitizer.sanitize(segment).sanitized);
        }
      }

      // The last segment is the filename; preceding segments form the
      // relative directory path.
      final sanitizedName = sanitizedSegments.last;
      final relativeDirs = sanitizedSegments.length > 1
          ? sanitizedSegments.sublist(0, sanitizedSegments.length - 1)
          : <String>[];

      // Build the full target path. If the mask produced an absolute path
      // (e.g. "C:\Music\Artist\..."), use it directly. Otherwise treat it
      // as relative to the file's current directory.
      final baseDirectory = _directoryOf(file.path);
      final String targetDir;
      if (relativeDirs.isEmpty) {
        targetDir = isAbsolute ? '' : baseDirectory;
      } else if (isAbsolute) {
        targetDir =
            '${relativeDirs.join(Platform.pathSeparator)}${Platform.pathSeparator}';
      } else {
        targetDir =
            '$baseDirectory${relativeDirs.join(Platform.pathSeparator)}${Platform.pathSeparator}';
      }
      final newFilename = '$sanitizedName${file.extension}';
      // For the preview display, show the full mask-produced path (including
      // any subdirectories) so the user can see where the file will end up.
      final newDisplayName = relativeDirs.isEmpty
          ? newFilename
          : '${relativeDirs.join(Platform.pathSeparator)}${Platform.pathSeparator}$newFilename';
      // Normalize the path to resolve ".." and "." segments.
      final newPath = p.normalize('$targetDir$newFilename');

      // Determine preview status.
      RenamePreviewStatus status;
      String? errorMessage;

      if (sanitizedName.isEmpty || sanitizedName.trim().isEmpty) {
        status = RenamePreviewStatus.error;
        errorMessage = 'Mask produced an empty filename';
      } else if (newPath == file.path) {
        status = RenamePreviewStatus.unchanged;
      } else {
        status = RenamePreviewStatus.ok;
        previewsMap[file.path] = newPath;
      }

      previews.add(
        RenamePreview(
          originalPath: file.path,
          originalFilename: file.filename,
          newPath: newPath,
          newFilename: newDisplayName,
          status: status,
          errorMessage: errorMessage,
        ),
      );
    }

    // Run conflict detection.
    final conflicts = _conflictDetector.detectConflicts(previewsMap);

    // Mark conflicting previews.
    final updatedPreviews = previews.map((preview) {
      if (preview.status == RenamePreviewStatus.ok &&
          conflicts.containsKey(preview.newPath)) {
        return RenamePreview(
          originalPath: preview.originalPath,
          originalFilename: preview.originalFilename,
          newPath: preview.newPath,
          newFilename: preview.newFilename,
          status: RenamePreviewStatus.conflict,
          errorMessage: 'Conflicts with another file',
        );
      }
      return preview;
    }).toList();

    state = state.copyWith(
      previews: updatedPreviews,
      conflicts: conflicts,
    );
  }

  /// Extracts the directory portion of a file path (including trailing separator).
  String _directoryOf(String path) {
    final lastSep = path.lastIndexOf(Platform.pathSeparator);
    if (lastSep == -1) return '';
    return path.substring(0, lastSep + 1);
  }

  /// Returns true if [path] is an absolute path (e.g. "C:\..." on Windows,
  /// or "/" on Unix).
  bool _isAbsolutePath(String path) {
    if (path.isEmpty) return false;
    if (Platform.isWindows) {
      // Matches drive letter patterns like "C:\" or "C:/"
      return path.length >= 3 &&
          RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(path);
    }
    return path.startsWith('/');
  }
}
