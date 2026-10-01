import 'package:flutter/material.dart';

import '../../data/models/shortcut_reference.dart';

/// Read-only reference of the app's keyboard shortcuts.
///
/// Every one of these was undiscoverable before: only Save, Undo and Redo
/// named their shortcut in a tooltip, and there was no help entry anywhere.
/// The bindings live in two places (the app-level CallbackShortcuts and the
/// grid's key handler), so the list is maintained in
/// [ShortcutReference] and grouped the way a user thinks about them rather
/// than the way the code is laid out.
class ShortcutHelpDialog extends StatelessWidget {
  const ShortcutHelpDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ShortcutHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.keyboard, size: 20),
          const SizedBox(width: 8),
          Text('Keyboard Shortcuts', style: theme.textTheme.titleMedium),
          const Spacer(),
          Text(
            '${ShortcutReference.total}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in ShortcutReference.groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    group.title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final (keys, description) in group.shortcuts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fixed-width key column so the descriptions line up
                        // and can be scanned.
                        SizedBox(
                          width: 190,
                          child: Text(
                            keys,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            description,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
