import 'package:flutter/material.dart';

/// Result of the threshold guard dialog.
enum ThresholdGuardResult {
  /// User chose to load all files.
  loadAll,

  /// User chose to load only top-level folder.
  topLevelOnly,

  /// User cancelled the operation.
  cancel,
}

/// A dialog warning the user about loading a large number of files.
///
/// Shows the detected file count and offers three options:
/// Load All, Top-Level Only, or Cancel.
class ThresholdGuardDialog extends StatelessWidget {
  const ThresholdGuardDialog({
    super.key,
    required this.fileCount,
  });

  /// The number of audio files detected.
  final int fileCount;

  /// Shows the dialog and returns the user's choice.
  static Future<ThresholdGuardResult?> show(
    BuildContext context, {
    required int fileCount,
  }) {
    return showDialog<ThresholdGuardResult>(
      context: context,
      builder: (_) => ThresholdGuardDialog(fileCount: fileCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, size: 32),
      title: const Text('Large Directory'),
      content: Text(
        'Found $fileCount audio files in subfolders.\n\n'
        'Loading this many files may take a moment. '
        'Would you like to proceed?',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ThresholdGuardResult.cancel),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pop(ThresholdGuardResult.topLevelOnly),
          child: const Text('Top-Level Only'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(ThresholdGuardResult.loadAll),
          child: const Text('Load All'),
        ),
      ],
    );
  }
}
