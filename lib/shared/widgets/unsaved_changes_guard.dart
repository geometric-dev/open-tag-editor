import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/undo/undo_redo_manager.dart';
import '../../features/error_handling/providers/error_providers.dart';
import '../../features/error_handling/utils/error_entry_factory.dart';
import '../../features/tag_editor/data/providers/editor_state_provider.dart';
import '../../features/tag_editor/data/providers/file_list_provider.dart';
import '../../features/tag_editor/data/providers/service_providers.dart';
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
  /// or the user cancelled the confirm-before-saving dialog.
  static Future<bool> _executeSave(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final files = ref.read(fileListProvider);
    final writer = ref.read(tagWriterProvider);
    final notifier = ref.read(fileListProvider.notifier);

    final modifiedFiles = files.where((f) => f.isModified).toList();
    if (modifiedFiles.isEmpty) return true;

    final fileTagsMap = <String, Map<String, String>>{};
    for (final file in modifiedFiles) {
      final changed = file.modifiedTags;
      if (changed.isNotEmpty) {
        fileTagsMap[file.path] = changed;
      }
    }

    if (fileTagsMap.isEmpty) return true;

    final results = await writer.writeTagsBatch(fileTagsMap);
    final failCount = results.where((r) => !r.success).length;

    // Mark successful files as no longer modified.
    final updatedFiles = modifiedFiles
        .where((f) => results.any((r) => r.path == f.path && r.success))
        .map((f) => f.copyWith(
              isModified: false,
              originalTags: Map<String, String>.unmodifiable(f.tags),
            ),)
        .toList();
    notifier.updateFiles(updatedFiles);

    if (failCount > 0) {
      // Report failures to error log
      final entries = ErrorEntryFactory.fromWriteResults(results, fileTagsMap);
      ref.read(errorLogProvider.notifier).addEntries(entries);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failCount file(s) failed to save'),
            duration: const Duration(seconds: 30),
            showCloseIcon: true,
            action: SnackBarAction(
              label: 'View Details',
              onPressed: () {
                ref.read(errorPanelVisibleProvider.notifier).state = true;
              },
            ),
          ),
        );
      }
      return false;
    }

    return true;
  }
}
