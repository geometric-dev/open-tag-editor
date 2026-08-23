import 'package:flutter/material.dart';

/// The action chosen by the user in the [UnsavedChangesDialog].
enum UnsavedChangesAction {
  save,
  discard,
  cancel,
}

/// A dialog that warns the user about unsaved changes and offers
/// options to save, discard, or cancel the current operation.
class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({
    super.key,
    required this.modifiedFileCount,
  });

  final int modifiedFileCount;

  /// Shows the [UnsavedChangesDialog] and returns the user's chosen action,
  /// or `null` if dismissed via the Escape key.
  static Future<UnsavedChangesAction?> show(
    BuildContext context,
    int modifiedFileCount,
  ) {
    return showDialog<UnsavedChangesAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnsavedChangesDialog(
        modifiedFileCount: modifiedFileCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Unsaved Changes'),
      content: Text(
        'You have unsaved changes to $modifiedFileCount file(s). '
        'What would you like to do?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            UnsavedChangesAction.cancel,
          ),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            UnsavedChangesAction.discard,
          ),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.error,
          ),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            UnsavedChangesAction.save,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
