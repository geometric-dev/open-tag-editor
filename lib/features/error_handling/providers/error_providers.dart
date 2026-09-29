import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/error_log_state.dart';
import '../notifiers/error_log_notifier.dart';

/// The error log notifier provider.
///
/// Manages the session error log with bounded capacity. Entries persist
/// across batch operations within a folder session and are cleared on
/// folder change.
final errorLogProvider = StateNotifierProvider<ErrorLogNotifier, ErrorLogState>(
  (ref) => ErrorLogNotifier(),
);

/// Whether the error panel is currently visible.
///
/// Toggled by the status bar error count or the snackbar "View Details"
/// action. Not reset on folder change so the user can keep it open.
final errorPanelVisibleProvider = StateProvider<bool>((ref) => false);

/// Derived provider: current error count for the status bar.
///
/// Returns the number of entries in the error log. The status bar watches
/// this to show or hide the error count badge.
final errorCountProvider = Provider<int>(
  (ref) => ref.watch(errorLogProvider).count,
);

/// Whether a retry operation is currently in progress.
///
/// Set to true while [RetryService] is executing retries. UI buttons
/// (e.g. "Retry All Failed") watch this to disable themselves.
final isRetryingProvider = StateProvider<bool>((ref) => false);
