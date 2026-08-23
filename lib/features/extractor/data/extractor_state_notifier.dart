import 'package:flutter_riverpod/legacy.dart';

import '../../../core/undo/undo_redo_manager.dart';
import '../../../shared/models/audio_file.dart';
import '../../renamer/data/mask_parser.dart';
import '../../renamer/data/models/case_option.dart';
import '../../renamer/data/models/mask_parse_exception.dart';
import '../../tag_editor/data/providers/file_list_provider.dart';
import 'mask_extractor.dart';
import 'models/extraction_preview.dart';
import 'models/extractor_state.dart';
import 'models/path_scope.dart';
import 'models/write_execution_result.dart';
import 'models/write_mode.dart';
import 'path_scope_resolver.dart';
import 'value_transformer.dart';
import 'write_tags_command.dart';

/// Manages extraction dialog state including pattern, scope, options, and
/// previews.
class ExtractorStateNotifier extends StateNotifier<ExtractorState> {
  ExtractorStateNotifier({
    required this.files,
    required this.rootFolder,
    required this.undoRedoManager,
    required this.fileListNotifier,
    MaskParser? parser,
    MaskExtractor? extractor,
    PathScopeResolver? scopeResolver,
    ValueTransformer? valueTransformer,
  })  : _parser = parser ?? MaskParser(),
        _extractor = extractor ?? const MaskExtractor(),
        _scopeResolver = scopeResolver ?? const PathScopeResolver(),
        _valueTransformer = valueTransformer ?? const ValueTransformer(),
        super(const ExtractorState());

  /// The list of audio files to extract tags from.
  final List<AudioFile> files;

  /// The root folder path for relative path resolution.
  final String rootFolder;

  /// The undo/redo manager for registering write commands.
  final UndoRedoManager undoRedoManager;

  /// The file list notifier for updating file tags in-memory.
  final FileListNotifier fileListNotifier;

  final MaskParser _parser;
  final MaskExtractor _extractor;
  final PathScopeResolver _scopeResolver;
  final ValueTransformer _valueTransformer;

  /// Updates the mask pattern and regenerates previews.
  void setPattern(String pattern) {
    try {
      final tokens = _parser.parse(pattern);
      final extractionError = _extractor.validateForExtraction(tokens);
      state = state.copyWith(
        pattern: pattern,
        tokens: tokens,
        parseError: null,
        extractionError: extractionError,
      );
    } on MaskParseException catch (e) {
      state = state.copyWith(
        pattern: pattern,
        tokens: const [],
        parseError: e.message,
        extractionError: null,
      );
    }
    _regeneratePreviews();
  }

  /// Updates the path scope and regenerates previews.
  void setPathScope(PathScope scope) {
    state = state.copyWith(pathScope: scope);
    _regeneratePreviews();
  }

  /// Updates the case transformation option and regenerates previews.
  void setCaseOption(CaseOption option) {
    state = state.copyWith(caseOption: option);
    _regeneratePreviews();
  }

  /// Toggles "replace underscores with spaces" and regenerates previews.
  void setReplaceUnderscores(bool value) {
    state = state.copyWith(replaceUnderscores: value);
    _regeneratePreviews();
  }

  /// Toggles "trim whitespace" and regenerates previews.
  void setTrimWhitespace(bool value) {
    state = state.copyWith(trimWhitespace: value);
    _regeneratePreviews();
  }

  /// Sets the write mode (overwrite existing vs. only fill empty).
  void setWriteMode(WriteMode mode) {
    state = state.copyWith(writeMode: mode);
  }

  /// Toggles selection of a specific file for writing.
  void toggleFileSelection(String filePath) {
    final current = Set<String>.from(state.deselectedFiles);
    if (current.contains(filePath)) {
      current.remove(filePath);
    } else {
      current.add(filePath);
    }
    state = state.copyWith(deselectedFiles: current);
  }

  /// Executes the write operation for all selected, matched files.
  ///
  /// Returns a [WriteExecutionResult] summarizing the operation.
  Future<WriteExecutionResult> writeTags() async {
    state = state.copyWith(isWriting: true);

    try {
      // Collect files to write: matched and not deselected.
      final filesToWrite = state.previews
          .where(
            (p) => p.matched && !state.deselectedFiles.contains(p.filePath),
          )
          .toList();

      if (filesToWrite.isEmpty) {
        const result = WriteExecutionResult(
          writtenCount: 0,
          skippedCount: 0,
          errorCount: 0,
        );
        state = state.copyWith(isWriting: false, writeResult: result);
        return result;
      }

      // Build extracted values and previous values maps.
      final filePaths = <String>[];
      final extractedValues = <String, Map<String, String>>{};
      final previousValues = <String, Map<String, String>>{};

      for (final preview in filesToWrite) {
        filePaths.add(preview.filePath);
        extractedValues[preview.filePath] = preview.transformedTags;

        // Capture current tag state for undo.
        final currentFile = files.firstWhere(
          (f) => f.path == preview.filePath,
          orElse: () => files.first,
        );
        previousValues[preview.filePath] =
            Map<String, String>.from(currentFile.tags);
      }

      // Create and execute the command.
      final command = WriteTagsCommand(
        fileListNotifier: fileListNotifier,
        filePaths: filePaths,
        extractedValues: extractedValues,
        previousValues: previousValues,
        writeMode: state.writeMode,
      );

      final result = command.executeWithResult();

      // Register with undo manager (only if something was written).
      if (result.writtenCount > 0) {
        // The command already executed via executeWithResult, so we add it
        // directly to the undo stack without re-executing.
        undoRedoManager.execute(_NoOpWrapperCommand(command));
      }

      state = state.copyWith(isWriting: false, writeResult: result);
      return result;
    } catch (e) {
      final result = WriteExecutionResult(
        writtenCount: 0,
        skippedCount: 0,
        errorCount: 1,
        errors: [WriteError(filePath: '', message: e.toString())],
      );
      state = state.copyWith(isWriting: false, writeResult: result);
      return result;
    }
  }

  /// Regenerates previews for all files based on current state.
  void _regeneratePreviews() {
    if (state.tokens.isEmpty ||
        state.parseError != null ||
        state.extractionError != null) {
      state = state.copyWith(previews: const []);
      return;
    }

    final previews = <ExtractionPreview>[];

    for (final file in files) {
      // Resolve path based on scope.
      final resolvedPath = _scopeResolver.resolve(
        file,
        state.pathScope,
        rootFolder,
      );

      // Extract tag values.
      final result = _extractor.extract(state.tokens, resolvedPath);

      // Apply transformations if matched.
      const Map<String, String> emptyTags = {};
      Map<String, String> transformedTags = emptyTags;
      if (result.matched && result.extractedTags.isNotEmpty) {
        transformedTags = _valueTransformer.transformAll(
          result.extractedTags,
          caseOption: state.caseOption,
          replaceUnderscores: state.replaceUnderscores,
          trimWhitespace: state.trimWhitespace,
        );
      }

      previews.add(
        ExtractionPreview(
          filePath: file.path,
          filename: file.filename,
          matched: result.matched,
          extractedTags: result.extractedTags,
          transformedTags: transformedTags,
        ),
      );
    }

    state = state.copyWith(previews: previews);
  }
}

/// Wrapper that delegates undo to the original command but skips execute
/// (since the command was already executed via [executeWithResult]).
class _NoOpWrapperCommand implements UndoableCommand {
  _NoOpWrapperCommand(this._inner);

  final WriteTagsCommand _inner;

  @override
  String get description => _inner.description;

  @override
  void execute() {
    // Re-execute on redo.
    _inner.execute();
  }

  @override
  void undo() => _inner.undo();
}
