import '../../../renamer/data/models/case_option.dart';
import '../../../renamer/data/models/mask_token.dart';
import 'extraction_preview.dart';
import 'path_scope.dart';
import 'write_execution_result.dart';
import 'write_mode.dart';

/// Complete state of the extraction dialog.
class ExtractorState {
  const ExtractorState({
    this.pattern = '',
    this.tokens = const [],
    this.parseError,
    this.extractionError,
    this.pathScope = PathScope.relativePath,
    this.caseOption = CaseOption.none,
    this.replaceUnderscores = false,
    this.trimWhitespace = true,
    this.writeMode = WriteMode.overwriteExisting,
    this.previews = const [],
    this.deselectedFiles = const {},
    this.isWriting = false,
    this.writeResult,
  });

  /// The current mask pattern string.
  final String pattern;

  /// Parsed tokens from the pattern.
  final List<MaskToken> tokens;

  /// Parse error message (invalid variable name, etc.).
  final String? parseError;

  /// Extraction validation error (e.g., adjacent variables without separator).
  final String? extractionError;

  /// Selected path scope.
  final PathScope pathScope;

  /// Selected case transformation.
  final CaseOption caseOption;

  /// Whether to replace underscores with spaces in extracted values.
  final bool replaceUnderscores;

  /// Whether to trim whitespace from extracted values.
  final bool trimWhitespace;

  /// Write mode (overwrite vs. fill empty).
  final WriteMode writeMode;

  /// Extraction preview for each file.
  final List<ExtractionPreview> previews;

  /// Set of file paths the user has deselected from writing.
  final Set<String> deselectedFiles;

  /// Whether a write operation is in progress.
  final bool isWriting;

  /// Result of the last write operation.
  final WriteExecutionResult? writeResult;

  /// Number of files that matched the mask.
  int get matchedCount => previews.where((p) => p.matched).length;

  /// Number of files that did not match.
  int get unmatchedCount => previews.where((p) => !p.matched).length;

  /// Number of files selected for writing (matched and not deselected).
  int get selectedForWriteCount => previews
      .where((p) => p.matched && !deselectedFiles.contains(p.filePath))
      .length;

  /// Creates a copy with updated fields.
  ExtractorState copyWith({
    String? pattern,
    List<MaskToken>? tokens,
    String? parseError,
    String? extractionError,
    PathScope? pathScope,
    CaseOption? caseOption,
    bool? replaceUnderscores,
    bool? trimWhitespace,
    WriteMode? writeMode,
    List<ExtractionPreview>? previews,
    Set<String>? deselectedFiles,
    bool? isWriting,
    WriteExecutionResult? writeResult,
  }) {
    return ExtractorState(
      pattern: pattern ?? this.pattern,
      tokens: tokens ?? this.tokens,
      parseError: parseError ?? this.parseError,
      extractionError: extractionError ?? this.extractionError,
      pathScope: pathScope ?? this.pathScope,
      caseOption: caseOption ?? this.caseOption,
      replaceUnderscores: replaceUnderscores ?? this.replaceUnderscores,
      trimWhitespace: trimWhitespace ?? this.trimWhitespace,
      writeMode: writeMode ?? this.writeMode,
      previews: previews ?? this.previews,
      deselectedFiles: deselectedFiles ?? this.deselectedFiles,
      isWriting: isWriting ?? this.isWriting,
      writeResult: writeResult ?? this.writeResult,
    );
  }
}
