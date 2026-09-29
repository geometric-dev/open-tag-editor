import 'case_option.dart';
import 'conflict_strategy.dart';
import 'mask_token.dart';
import 'rename_execution_result.dart';
import 'rename_preview.dart';

/// Complete state of the rename dialog.
class RenamerState {
  const RenamerState({
    this.pattern = '',
    this.tokens = const [],
    this.parseError,
    this.caseOption = CaseOption.none,
    this.replaceUnderscores = false,
    this.conflictStrategy = ConflictStrategy.skip,
    this.previews = const [],
    this.conflicts = const {},
    this.isExecuting = false,
    this.executionResult,
  });

  /// The current mask pattern string.
  final String pattern;

  /// Parsed tokens from the pattern.
  final List<MaskToken> tokens;

  /// Parse error message, if the pattern is invalid.
  final String? parseError;

  /// Selected case transformation option.
  final CaseOption caseOption;

  /// Whether to replace underscores with spaces.
  final bool replaceUnderscores;

  /// Selected conflict resolution strategy.
  final ConflictStrategy conflictStrategy;

  /// Preview of rename results for all files.
  final List<RenamePreview> previews;

  /// Detected conflicts: target path → list of source paths.
  final Map<String, List<String>> conflicts;

  /// Whether a rename operation is currently executing.
  final bool isExecuting;

  /// Result of the last rename execution.
  final RenameExecutionResult? executionResult;

  /// Creates a copy with updated fields.
  ///
  /// For nullable fields ([parseError], [executionResult]), pass the
  /// sentinel [_absent] via the wrapper parameters [clearParseError] and
  /// [clearExecutionResult] to explicitly set them to null.
  RenamerState copyWith({
    String? pattern,
    List<MaskToken>? tokens,
    Object? parseError = _absent,
    CaseOption? caseOption,
    bool? replaceUnderscores,
    ConflictStrategy? conflictStrategy,
    List<RenamePreview>? previews,
    Map<String, List<String>>? conflicts,
    bool? isExecuting,
    Object? executionResult = _absent,
  }) {
    return RenamerState(
      pattern: pattern ?? this.pattern,
      tokens: tokens ?? this.tokens,
      parseError: parseError == _absent
          ? this.parseError
          : parseError as String?,
      caseOption: caseOption ?? this.caseOption,
      replaceUnderscores: replaceUnderscores ?? this.replaceUnderscores,
      conflictStrategy: conflictStrategy ?? this.conflictStrategy,
      previews: previews ?? this.previews,
      conflicts: conflicts ?? this.conflicts,
      isExecuting: isExecuting ?? this.isExecuting,
      executionResult: executionResult == _absent
          ? this.executionResult
          : executionResult as RenameExecutionResult?,
    );
  }
}

const _absent = Object();
