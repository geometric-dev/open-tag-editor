import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/providers/settings_providers.dart';
import '../../features/tag_editor/data/providers/editor_state_provider.dart';

/// Asks the user to confirm before tags are written to disk.
///
/// Honours the "Confirm before saving tags" setting. When the setting is off
/// — the default — this returns `true` immediately, so the save path costs
/// nothing in the common case.
///
/// Every entry point that writes tags (toolbar, Ctrl+S, the tag panel, and
/// the unsaved-changes guard) calls this, so turning the setting on
/// cannot be bypassed by using a different route to the same write.
class SaveConfirmation {
  /// Returns whether the save may proceed.
  static Future<bool> confirmIfNeeded({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    if (!ref.read(generalSettingsProvider).confirmBeforeSave) return true;

    // Nothing to write: do not interrupt a no-op save with a prompt.
    final count = ref.read(modifiedFileCountProvider);
    if (count == 0) return true;
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save tags?'),
        content: Text(
          'Write tag changes to $count file(s)?\n\n'
          'Files are modified in place, after a temporary copy and validation. '
          'A .bak copy is kept if backups are enabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Dismissing the dialog is a cancel, not a silent save.
    return result ?? false;
  }
}
