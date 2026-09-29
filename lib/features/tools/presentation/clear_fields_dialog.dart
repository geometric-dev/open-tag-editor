import 'package:flutter/material.dart';

import '../../../../shared/models/audio_file.dart';
import '../data/tag_deletion_plan.dart';

/// Dialog for choosing which tag fields to remove from the current selection.
///
/// Lists only fields that actually carry a value somewhere in the selection
/// and marks fields that are partial, so "Select All" is a deliberate act
/// rather than a way to blank fields the user never populated. Returns the
/// chosen field names, or `null` if cancelled.
class ClearFieldsDialog extends StatefulWidget {
  const ClearFieldsDialog({super.key, required this.files});

  final List<AudioFile> files;

  /// Shows the dialog and returns the selected field names.
  static Future<Set<String>?> show(
    BuildContext context, {
    required List<AudioFile> files,
  }) {
    return showDialog<Set<String>>(
      context: context,
      builder: (_) => ClearFieldsDialog(files: files),
    );
  }

  @override
  State<ClearFieldsDialog> createState() => _ClearFieldsDialogState();
}

class _ClearFieldsDialogState extends State<ClearFieldsDialog> {
  late final List<FieldUsage> _fields = inventoryFields(widget.files);
  late final Set<String> _selected = _fields
      .where((f) => f.isUniversal)
      .map((f) => f.field)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileCount = widget.files.length;

    return AlertDialog(
      title: const Text('Clear Fields'),
      content: SizedBox(
        width: 440,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$fileCount file(s) selected. Unchecked fields are left alone.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // Wrap rather than Row: the two buttons plus the live count do
            // not fit on one line at every window width, and an overflow
            // in a modal is a hard test failure as well as ugly.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(
                    () => _selected
                      ..clear()
                      ..addAll(_fields.map((f) => f.field)),
                  ),
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Select None'),
                ),
                // Live preview so the user sees the blast radius before
                // confirming, rather than a generic "are you sure?".
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${_plan().affectedFileCount} file(s) affected',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: _fields.isEmpty
                  ? Center(
                      child: Text(
                        'No tag fields to clear',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _fields.length,
                      itemBuilder: (context, index) {
                        final usage = _fields[index];
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            usage.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            usage.isPartial
                                ? 'in ${usage.presentCount} of '
                                      '${usage.fileCount} files'
                                : 'in all ${usage.fileCount} files',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              // A partial field is the one most likely to
                              // surprise someone, so flag it visually as
                              // well as in the count.
                              color: usage.isPartial
                                  ? theme.colorScheme.tertiary
                                  : null,
                            ),
                          ),
                          value: _selected.contains(usage.field),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              _selected.add(usage.field);
                            } else {
                              _selected.remove(usage.field);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Clear'),
        ),
      ],
    );
  }

  /// Recomputes the plan against the live selection so the affected-file
  /// count cannot drift from what the button will actually do.
  ClearPlan _plan() => planClear(widget.files, _selected);
}
