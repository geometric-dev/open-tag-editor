import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateController;

import '../../features/error_handling/providers/error_providers.dart';
import '../../features/error_handling/utils/error_entry_factory.dart';
import '../../features/tag_editor/data/providers/editor_state_provider.dart';
import '../../features/tag_editor/data/providers/service_providers.dart';
import '../../features/tag_editor/data/services/tag_save_service.dart';
import 'save_confirmation.dart';

/// The one save flow, shared by every entry point.
///
/// The toolbar button, Ctrl+S, the tag panel and the unsaved-changes guard
/// all used to run their own copy of "confirm, save, log the failures,
/// report the outcome". They had already drifted: the toolbar and the guard
/// showed a failure snackbar while the tag panel and Ctrl+S showed nothing,
/// so a user pressing Ctrl+S with three failures saw a status-bar line
/// change and no other feedback at all. One implementation removes the
/// possibility of the next one drifting.
class SaveFlow {
  /// Saves every modified file, reporting the outcome.
  ///
  /// Returns `true` when the save completed with no failures. `false` means
  /// the user cancelled, or some files failed — in both cases nothing is
  /// reported as a success.
  static Future<bool> saveAll(
    BuildContext context,
    WidgetRef ref, {
    bool confirm = true,
  }) async {
    final status = ref.read(statusMessageProvider.notifier);

    if (confirm) {
      final proceed = await SaveConfirmation.confirmIfNeeded(
        context: context,
        ref: ref,
      );
      if (!proceed) {
        status.state = 'Save cancelled';
        return false;
      }
      if (!context.mounted) return false;
    }

    status.state = 'Saving...';
    final summary = await ref.read(tagSaveServiceProvider).saveAllModified();

    if (summary == null) {
      status.state = 'No changes to save';
      return true;
    }

    if (!context.mounted) return true;
    return _report(context, ref, status, summary);
  }

  /// Records failures and surfaces the outcome. Shared by [saveAll] and
  /// [saveAndProceed].
  static bool _report(
    BuildContext context,
    WidgetRef ref,
    StateController<String> status,
    TagSaveSummary summary,
  ) {
    final allSuccess = summary.allSuccess;

    if (!allSuccess) {
      ref
          .read(errorLogProvider.notifier)
          .addEntries(
            ErrorEntryFactory.fromWriteResults(
              summary.results,
              summary.attemptedTags,
            ),
          );
      status.state =
          'Saved ${summary.successCount} file(s), '
          '${summary.failureCount} failed';
    } else {
      status.state = 'Saved ${summary.successCount} file(s)';
    }

    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      // Failures clear the way: a success toast must not overwrite an
      // error the user has not read yet.
      if (!allSuccess) messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            allSuccess
                ? '${summary.successCount} file(s) saved successfully'
                : '${summary.failureCount} file(s) failed to save',
          ),
          // Errors persist until dismissed; success auto-hides.
          duration: Duration(seconds: allSuccess ? 3 : 30),
          showCloseIcon: !allSuccess,
          action: allSuccess
              ? null
              : SnackBarAction(
                  label: 'View Details',
                  onPressed: () {
                    ref.read(errorPanelVisibleProvider.notifier).state = true;
                  },
                ),
        ),
      );
    }

    return allSuccess;
  }

  /// Saves and reports, for callers that need the result rather than a
  /// user-facing message (the unsaved-changes guard).
  static Future<bool> saveAndProceed(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final status = ref.read(statusMessageProvider.notifier);
    final summary = await ref.read(tagSaveServiceProvider).saveAllModified();
    if (summary == null) return true;
    if (!context.mounted) return false;
    return _report(context, ref, status, summary);
  }
}
