import 'package:flutter/material.dart';

/// Result of the batch confirmation dialog.
enum BatchConfirmResult { yes, no, cancel }

/// Shows a dialog asking whether to apply an edit to all selected files.
///
/// Returns [BatchConfirmResult.yes], [BatchConfirmResult.no],
/// or [BatchConfirmResult.cancel].
Future<BatchConfirmResult> showBatchConfirmDialog(
  BuildContext context,
  int selectedCount,
) async {
  final result = await showDialog<BatchConfirmResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Apply to selection?'),
      content: Text(
        'Apply this edit to all $selectedCount selected files?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(BatchConfirmResult.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(BatchConfirmResult.no),
          child: const Text('No, just this file'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(BatchConfirmResult.yes),
          child: const Text('Yes, all selected'),
        ),
      ],
    ),
  );
  return result ?? BatchConfirmResult.cancel;
}
