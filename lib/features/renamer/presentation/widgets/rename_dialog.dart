import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/rename_result.dart';
import '../../../error_handling/providers/error_providers.dart';
import '../../../error_handling/utils/error_entry_factory.dart';
import '../../../settings/data/providers/settings_providers.dart';
import '../../data/models/case_option.dart';
import '../../data/models/conflict_strategy.dart';
import '../../data/models/rename_preview.dart';
import '../../data/models/tag_variable.dart';
import '../../data/providers/renamer_providers.dart';
import 'preview_panel.dart';

/// Main rename dialog using the mask-based architecture.
///
/// Allows users to define a mask pattern with tag variables, configure
/// case transformation and conflict resolution, preview results, and
/// execute the rename operation.
class RenameDialog extends ConsumerStatefulWidget {
  const RenameDialog({super.key});

  @override
  ConsumerState<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<RenameDialog> {
  final _patternController = TextEditingController();
  bool _showTagHelper = false;
  int? _selectedPresetIndex;

  @override
  void initState() {
    super.initState();
    final defaultPattern = ref.read(renamingSettingsProvider).defaultPattern;
    _patternController.text = defaultPattern;
    _selectedPresetIndex = ref.read(presetProvider).isNotEmpty ? 0 : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(renamerStateProvider.notifier).setPattern(defaultPattern);
    });
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  void _insertVariable(TagVariable variable) {
    final text = _patternController.text;
    final selection = _patternController.selection;
    final insert = '%${variable.maskName}';
    final newText = text.replaceRange(selection.start, selection.end, insert);
    _patternController.text = newText;
    _patternController.selection = TextSelection.collapsed(
      offset: selection.start + insert.length,
    );
    ref.read(renamerStateProvider.notifier).setPattern(newText);
  }

  Future<void> _executeRename() async {
    final notifier = ref.read(renamerStateProvider.notifier);
    final state = ref.read(renamerStateProvider);
    final result = await notifier.executeRename();
    if (mounted) {
      if (result.errorCount > 0) {
        // Convert RenameErrors to RenameResults for the error entry factory.
        final renameResults = result.errors.map((e) {
          // Look up the target path from previews.
          final preview = state.previews.cast<RenamePreview?>().firstWhere(
            (p) => p!.originalPath == e.filePath,
            orElse: () => null,
          );
          return RenameResult(
            originalPath: e.filePath,
            newPath: preview?.newPath ?? '',
            success: false,
            error: e.message,
          );
        }).toList();
        final entries = ErrorEntryFactory.fromRenameResults(renameResults);
        ref.read(errorLogProvider.notifier).addEntries(entries);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.renamedCount} renamed, ${result.errorCount} failed',
            ),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.renamedCount} renamed, ${result.skippedCount} skipped',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _savePreset() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save Preset'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Preset name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name != null && name.trim().isNotEmpty) {
      await ref
          .read(presetProvider.notifier)
          .save(name.trim(), _patternController.text);
    }
  }

  Future<void> _confirmDeletePreset(String presetName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Preset'),
          content: Text("Delete preset '$presetName'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && _selectedPresetIndex != null) {
      await ref.read(presetProvider.notifier).delete(_selectedPresetIndex!);
      setState(() {
        final presets = ref.read(presetProvider);
        if (presets.isEmpty) {
          _selectedPresetIndex = null;
        } else if (_selectedPresetIndex! >= presets.length) {
          _selectedPresetIndex = presets.length - 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(renamerStateProvider);
    final presets = ref.watch(presetProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final hasOkPreviews = state.previews.any(
      (p) => p.status == RenamePreviewStatus.ok,
    );
    final previewRequired = ref
        .watch(renamingSettingsProvider)
        .previewBeforeRenaming;
    final canExecute = previewRequired
        ? hasOkPreviews
        : state.pattern.isNotEmpty;

    return AlertDialog(
      title: const Text('Rename Files'),
      content: SizedBox(
        width: 700,
        height: 550,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Preset selector row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(presets.length),
                    initialValue: _selectedPresetIndex,
                    decoration: const InputDecoration(labelText: 'Preset'),
                    items: [
                      for (var i = 0; i < presets.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(presets[i].name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null && value < presets.length) {
                        final pattern = presets[value].pattern;
                        _patternController.text = pattern;
                        ref
                            .read(renamerStateProvider.notifier)
                            .setPattern(pattern);
                        setState(() => _selectedPresetIndex = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete preset',
                  onPressed:
                      _selectedPresetIndex == null ||
                          presets.isEmpty ||
                          presets[_selectedPresetIndex!].isBuiltIn
                      ? null
                      : () => _confirmDeletePreset(
                          presets[_selectedPresetIndex!].name,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Mask pattern input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _patternController,
                    decoration: const InputDecoration(
                      labelText: 'Mask Pattern',
                      hintText: '%artist - %title',
                    ),
                    onChanged: (value) {
                      ref.read(renamerStateProvider.notifier).setPattern(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _showTagHelper ? Icons.expand_less : Icons.expand_more,
                  ),
                  tooltip: 'Toggle tag variable helper',
                  onPressed: () {
                    setState(() => _showTagHelper = !_showTagHelper);
                  },
                ),
              ],
            ),
            if (state.parseError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.parseError!,
                  style: TextStyle(fontSize: 12, color: colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),

            // 3. Tag variable helper (shown/hidden)
            if (_showTagHelper)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final variable in TagVariable.values)
                      ActionChip(
                        label: Text(
                          variable.displayName,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _insertVariable(variable),
                      ),
                  ],
                ),
              ),

            // 4. Options row
            Row(
              children: [
                // Case transformation
                Flexible(
                  child: DropdownButton<CaseOption>(
                    value: state.caseOption,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: [
                      for (final option in CaseOption.values)
                        DropdownMenuItem(
                          value: option,
                          child: Text(
                            option.displayName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(renamerStateProvider.notifier)
                            .setCaseOption(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Replace underscores checkbox
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: state.replaceUnderscores,
                      onChanged: (value) {
                        ref
                            .read(renamerStateProvider.notifier)
                            .setReplaceUnderscores(value ?? false);
                      },
                    ),
                    const Text(
                      'Replace underscores with spaces',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Conflict strategy
                Flexible(
                  child: DropdownButton<ConflictStrategy>(
                    value: state.conflictStrategy,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: [
                      for (final strategy in ConflictStrategy.values)
                        DropdownMenuItem(
                          value: strategy,
                          child: Text(
                            strategy.displayName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(renamerStateProvider.notifier)
                            .setConflictStrategy(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Preview panel
            Expanded(child: PreviewPanel(previews: state.previews)),
          ],
        ),
      ),
      // 6. Actions row
      actions: [
        TextButton(
          onPressed: state.isExecuting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: state.isExecuting ? null : _savePreset,
          child: const Text('Save Preset'),
        ),
        FilledButton(
          onPressed: state.isExecuting || !canExecute ? null : _executeRename,
          child: state.isExecuting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Rename'),
        ),
      ],
    );
  }
}
