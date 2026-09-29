import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/undo/undo_redo_manager.dart';
import '../../features/tag_editor/data/providers/editor_state_provider.dart';
import 'save_confirmation.dart';
import 'save_flow.dart';
import 'unsaved_changes_dialog.dart';

/// Utility that checks for unsaved changes and shows a guard dialog if needed.
///
/// Returns `true` if the caller should proceed with the destructive action
/// (either no dirty state, or user chose Save/Discard).
/// Returns `false` if the action was cancelled.
class UnsavedChangesGuard {
  /// Checks for unsaved changes and prompts the user if any exist.
  ///
  /// If [clearUndoOnDiscard] is true, the undo history is cleared when the
  /// user chooses Discard (appropriate for folder/file load operations where
  /// the app continues running).
  static Future<bool> check({
    required BuildContext context,
    required WidgetRef ref,
    bool clearUndoOnDiscard = false,
  }) async {
    final hasDirty = ref.read(hasUnsavedChangesProvider);
    if (!hasDirty) return true;

    final count = ref.read(modifiedFileCountProvider);
    final action = await UnsavedChangesDialog.show(context, count);

    switch (action) {
      case UnsavedChangesAction.save:
        if (!context.mounted) return false;
        final success = await _executeSave(context, ref);
        return success;
      case UnsavedChangesAction.discard:
        if (clearUndoOnDiscard) {
          ref.read(undoRedoProvider.notifier).clear();
        }
        return true;
      case UnsavedChangesAction.cancel:
      case null:
        return false;
    }
  }

  /// Executes the full save flow for all modified files.
  ///
  /// Returns `true` if all files saved successfully, `false` if any failed
  /// or the user cancelled either the confirm-before-saving dialog or the
  /// save itself.
  static Future<bool> _executeSave(BuildContext context, WidgetRef ref) async {
    // The user has already committed to saving by choosing "Save" in the
    // unsaved-changes dialog, so this re-prompt only applies when the
    // setting is on; it stays consistent with every other save route.
    if (!await SaveConfirmation.confirmIfNeeded(context: context, ref: ref)) {
      return false;
    }
    if (!context.mounted) return false;

    return SaveFlow.saveAndProceed(context, ref);
  }
}
