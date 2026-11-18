import 'package:flutter/material.dart';

/// Modal dialog shown on first app start asking the user whether to enable auto-updates.
class FirstStartUpdateDialog extends StatelessWidget {
  const FirstStartUpdateDialog({super.key});

  /// Displays the first-start update preferences dialog.
  ///
  /// Returns `true` if the user chose "Auto-update", `false` if "Don't auto-update",
  /// or `null` if dismissed without an explicit choice.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstStartUpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Row(
        children: [
          Icon(
            Icons.system_update_rounded,
            size: 22,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          const Text('Enable Auto-Updates?'),
        ],
      ),
      content: const SizedBox(
        width: 440,
        child: Text(
          'Open Tag Editor can automatically check for updates on GitHub in the '
          'background and keep you on the latest version.\n\n'
          'You can change this anytime in Settings.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Don't auto-update"),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Auto-update'),
        ),
      ],
    );
  }
}
