import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/services/tag_reader_service.dart';
import '../models/error_entry.dart';
import '../models/operation_context.dart';
import '../notifiers/error_log_notifier.dart';

/// Replays failed operations from the error log using stored context.
///
/// Each retry dispatches to the appropriate service (tag reader, tag writer,
/// or file system rename) based on the entry's [OperationContext] type.
/// The [isRetryingController] is set during operations so the UI can
/// disable retry buttons.
class RetryService {
  /// Creates a [RetryService] with the required dependencies.
  RetryService({
    required this.errorLogNotifier,
    required this.tagReader,
    required this.tagWriter,
    required this.isRetryingController,
  });

  /// The error log notifier for reading/removing/updating entries.
  final ErrorLogNotifier errorLogNotifier;

  /// Service for retrying failed tag read operations.
  final TagReaderService tagReader;

  /// Service for retrying failed tag write operations.
  final TagWriterService tagWriter;

  /// Controller to set the retrying state for UI feedback.
  final StateController<bool> isRetryingController;

  /// Retries all failed operations in the error log.
  ///
  /// Iterates every entry, attempts to replay the operation, removes
  /// successful entries, and updates failed entries with the new error.
  /// Returns the count of successful retries.
  Future<int> retryAll() async {
    isRetryingController.state = true;
    try {
      var successCount = 0;
      // Online-lookup entries are informational only (see isRetryable);
      // they are skipped, not failed, so their log entries persist.
      final entries = errorLogNotifier.currentState.entries
          .where((e) => e.isRetryable)
          .toList();

      for (final entry in entries) {
        try {
          await _retryEntry(entry);
          errorLogNotifier.removeEntry(entry.id);
          successCount++;
        } on Exception catch (e) {
          errorLogNotifier.updateEntry(
            entry.id,
            newMessage: e.toString(),
            newTimestamp: DateTime.now(),
          );
        }
      }

      return successCount;
    } finally {
      isRetryingController.state = false;
    }
  }

  /// Retries a single failed operation by entry ID.
  ///
  /// Returns `true` if the retry succeeded, `false` otherwise.
  Future<bool> retrySingle(String entryId) async {
    isRetryingController.state = true;
    try {
      final entry = errorLogNotifier.currentState.entries.firstWhere(
        (e) => e.id == entryId,
      );

      // Defensive: lookup entries have no retry button in the UI.
      if (!entry.isRetryable) return false;

      try {
        await _retryEntry(entry);
        errorLogNotifier.removeEntry(entry.id);
        return true;
      } on Exception catch (e) {
        errorLogNotifier.updateEntry(
          entry.id,
          newMessage: e.toString(),
          newTimestamp: DateTime.now(),
        );
        return false;
      }
    } finally {
      isRetryingController.state = false;
    }
  }

  /// Dispatches the retry to the appropriate service based on context type.
  Future<void> _retryEntry(ErrorEntry entry) async {
    final context = entry.operationContext;
    switch (context) {
      case ReadOperationContext():
        await tagReader.readTags(context.filePath);
      case WriteOperationContext():
        await tagWriter.writeTags(context.filePath, context.tags);
      case RenameOperationContext():
        await File(context.filePath).rename(context.targetPath);
      case LookupOperationContext():
        // Unreachable: retryAll/retrySingle filter non-retryable entries
        // via ErrorEntry.isRetryable before dispatching.
        throw UnsupportedError(
          'Online lookup failures cannot be auto-retried',
        );
    }
  }
}
