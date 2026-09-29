import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../shared/models/rename_result.dart';
import '../../../shared/services/tag_reader_service.dart';
import '../models/error_entry.dart';
import '../models/operation_context.dart';
import '../models/operation_type.dart';

/// Static factory for creating [ErrorEntry] instances from batch operation
/// results.
///
/// Each factory method filters for failed results and produces one
/// [ErrorEntry] per failure with the appropriate [OperationContext] for
/// retry support.
class ErrorEntryFactory {
  const ErrorEntryFactory._();

  static const _uuid = Uuid();

  /// Creates [ErrorEntry] instances from failed tag write results.
  ///
  /// Only results where [TagWriteResult.success] is `false` produce entries.
  /// The [originalTags] map provides the tag data that was being written,
  /// keyed by file path, which is stored in [WriteOperationContext] for
  /// retry.
  static List<ErrorEntry> fromWriteResults(
    List<TagWriteResult> results,
    Map<String, Map<String, String>> originalTags,
  ) {
    final now = DateTime.now();
    return results
        .where((r) => !r.success)
        .map(
          (r) => ErrorEntry(
            id: _uuid.v4(),
            filePath: r.path,
            fileName: p.basename(r.path),
            operationType: OperationType.write,
            errorMessage: r.error ?? 'Unknown write error',
            timestamp: now,
            operationContext: WriteOperationContext(
              filePath: r.path,
              tags: originalTags[r.path] ?? const {},
            ),
          ),
        )
        .toList();
  }

  /// Creates [ErrorEntry] instances from failed rename results.
  ///
  /// Only results where [RenameResult.success] is `false` produce entries.
  /// The [RenameOperationContext] stores both the original and target paths
  /// for retry.
  static List<ErrorEntry> fromRenameResults(List<RenameResult> results) {
    final now = DateTime.now();
    return results
        .where((r) => !r.success)
        .map(
          (r) => ErrorEntry(
            id: _uuid.v4(),
            filePath: r.originalPath,
            fileName: p.basename(r.originalPath),
            operationType: OperationType.rename,
            errorMessage: r.error ?? 'Unknown rename error',
            timestamp: now,
            operationContext: RenameOperationContext(
              filePath: r.originalPath,
              targetPath: r.newPath,
            ),
          ),
        )
        .toList();
  }

  /// Creates a single informational entry for a failed online lookup.
  ///
  /// These entries are not auto-retryable; they exist so network/API
  /// failures are visible in the session log instead of surfacing only
  /// inside the lookup dialog.
  static ErrorEntry fromLookupFailure({
    required String summary,
    required String message,
  }) {
    return ErrorEntry(
      id: _uuid.v4(),
      filePath: summary,
      fileName: summary,
      operationType: OperationType.onlineLookup,
      errorMessage: message,
      timestamp: DateTime.now(),
      operationContext: LookupOperationContext(description: summary),
    );
  }

  /// Creates a single [ErrorEntry] for a failed tag write on [path].
  ///
  /// Retryable, because a tag write that failed once commonly succeeds on a
  /// retry. Callers that file a write failure as a *lookup* failure get an
  /// error panel that cannot offer retry, which is why this exists.
  static ErrorEntry fromWriteFailure({
    required String path,
    required String message,
  }) {
    return ErrorEntry(
      id: _uuid.v4(),
      filePath: path,
      fileName: p.basename(path),
      operationType: OperationType.write,
      errorMessage: message,
      timestamp: DateTime.now(),
      operationContext: WriteOperationContext(
        filePath: path,
        // The tag delta is not known to this factory. Retry re-reads the
        // file from disk rather than replaying a write, which is the safe
        // direction: it cannot re-apply stale values over newer data.
        tags: const {},
      ),
    );
  }

  /// Creates [ErrorEntry] instances from file paths that failed tag reading.
  ///
  /// The [errorMessages] map provides the error message for each failed path.
  /// Each entry uses [ReadOperationContext] with the file path for retry.
  static List<ErrorEntry> fromReadFailures(
    List<String> failedPaths,
    Map<String, String> errorMessages,
  ) {
    final now = DateTime.now();
    return failedPaths
        .map(
          (path) => ErrorEntry(
            id: _uuid.v4(),
            filePath: path,
            fileName: p.basename(path),
            operationType: OperationType.read,
            errorMessage: errorMessages[path] ?? 'Unknown read error',
            timestamp: now,
            operationContext: ReadOperationContext(filePath: path),
          ),
        )
        .toList();
  }
}
