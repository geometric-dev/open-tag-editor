import 'package:flutter_riverpod/legacy.dart';

import '../models/error_entry.dart';
import '../models/error_log_state.dart';

/// Maximum number of entries the error log can hold.
///
/// When the log reaches this capacity, the oldest entries are evicted
/// (FIFO) to make room for new ones.
const int maxErrorLogCapacity = 500;

/// Manages the session error log with a bounded capacity of [maxErrorLogCapacity] entries.
///
/// The notifier maintains insertion order (newest last) and automatically
/// evicts the oldest entries when the log is full. The log persists across
/// batch operations within a folder session and is cleared on folder change.
class ErrorLogNotifier extends StateNotifier<ErrorLogState> {
  /// Creates an [ErrorLogNotifier] with an empty initial state.
  ErrorLogNotifier() : super(const ErrorLogState());

  /// The current error log state.
  ///
  /// Exposed for services that need to read entries without being a
  /// subclass of this notifier (e.g. [RetryService]).
  ErrorLogState get currentState => state;

  /// Adds one or more error entries to the log.
  ///
  /// If appending [entries] would exceed [maxErrorLogCapacity], the oldest
  /// entries are evicted first (FIFO) so the total never exceeds the limit.
  void addEntries(List<ErrorEntry> entries) {
    if (entries.isEmpty) return;

    final combined = [...state.entries, ...entries];
    final overflow = combined.length - maxErrorLogCapacity;

    state = ErrorLogState(
      entries: overflow > 0 ? combined.sublist(overflow) : combined,
    );
  }

  /// Removes the entry with the given [entryId] from the log.
  ///
  /// Typically called after a successful retry operation.
  /// Does nothing if no entry with [entryId] exists.
  void removeEntry(String entryId) {
    state = ErrorLogState(
      entries: state.entries.where((e) => e.id != entryId).toList(),
    );
  }

  /// Updates an existing entry in-place with a new error message and timestamp.
  ///
  /// Preserves the entry's [ErrorEntry.id] and [ErrorEntry.operationContext].
  /// Typically called after a failed retry to reflect the latest error.
  /// Does nothing if no entry with [entryId] exists.
  void updateEntry(
    String entryId, {
    required String newMessage,
    required DateTime newTimestamp,
  }) {
    state = ErrorLogState(
      entries: state.entries.map((e) {
        if (e.id == entryId) {
          return e.copyWith(errorMessage: newMessage, timestamp: newTimestamp);
        }
        return e;
      }).toList(),
    );
  }

  /// Clears all entries from the log.
  ///
  /// Called when the user loads a new folder to reset the session error state.
  void clear() {
    state = const ErrorLogState();
  }
}
