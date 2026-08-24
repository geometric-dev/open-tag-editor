import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../renamer/data/models/case_option.dart';
import '../../../renamer/data/models/tag_variable.dart';
import '../../../renamer/data/providers/renamer_providers.dart';
import '../../data/models/path_scope.dart';
import '../../data/models/write_mode.dart';
import '../../data/providers/extractor_providers.dart';
import 'extractor_preview_panel.dart';

/// Main dialog for extracting tags from filenames using mask patterns.
///
/// Allows users to define a mask pattern, configure path scope and
/// transformation options, preview extracted values, and write tags.
class ExtractorDialog extends ConsumerStatefulWidget {
  const ExtractorDialog({super.key});

  @override
  ConsumerState<ExtractorDialog> createState() => _ExtractorDialogState();
}

class _ExtractorDialogState extends ConsumerState<ExtractorDialog> {
  final _patternController = TextEditingController();
  bool _showTagHelper = false;

  @override
  void initState() {
    super.initState();
    final presets = ref.read(presetProvider);
    if (presets.isNotEmpty) {
      _patternController.text = presets.first.pattern;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(extractorStateProvider.notifier)
            .setPattern(presets.first.pattern);
      });
    }
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
    ref.read(extractorStateProvider.notifier).setPattern(newText);
  }

  Future<void> _writeTags() async {
    final notifier = ref.read(extractorStateProvider.notifier);
    final result = await notifier.writeTags();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.writtenCount} written, '
            '${result.skippedCount} skipped, '
            '${result.errorCount} errors',
          ),
        ),
      );
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
            decoration: const InputDecoration(
              labelText: 'Preset name',
            ),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(extractorStateProvider);
    final presets = ref.watch(presetProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final hasMatches = state.selectedForWriteCount > 0;

    return AlertDialog(
      title: const Text('Tags from Filename'),
      content: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Preset selector
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Preset',
                isDense: true,
              ),
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
                  ref.read(extractorStateProvider.notifier).setPattern(pattern);
                }
              },
            ),
            const SizedBox(height: 12),

            // 2. Mask pattern input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _patternController,
                    decoration: const InputDecoration(
                      labelText: 'Mask Pattern',
                      hintText: '%artist/%album/%track - %title',
                    ),
                    onChanged: (value) {
                      ref
                          .read(extractorStateProvider.notifier)
                          .setPattern(value);
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

            // Error messages
            if (state.parseError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.parseError!,
                  style: TextStyle(fontSize: 12, color: colorScheme.error),
                ),
              ),
            if (state.extractionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.extractionError!,
                  style: TextStyle(fontSize: 12, color: colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),

            // 3. Tag variable helper
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
                    ActionChip(
                      label: const Text(
                        'Ignore',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () {
                        final text = _patternController.text;
                        final selection = _patternController.selection;
                        const insert = '%ignore';
                        final newText = text.replaceRange(
                          selection.start,
                          selection.end,
                          insert,
                        );
                        _patternController.text = newText;
                        _patternController.selection = TextSelection.collapsed(
                          offset: selection.start + insert.length,
                        );
                        ref
                            .read(extractorStateProvider.notifier)
                            .setPattern(newText);
                      },
                    ),
                  ],
                ),
              ),

            // 4. Options row
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Path scope
                DropdownButton<PathScope>(
                  value: state.pathScope,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: [
                    for (final scope in PathScope.values)
                      DropdownMenuItem(
                        value: scope,
                        child: Text(
                          scope.displayName,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(extractorStateProvider.notifier)
                          .setPathScope(value);
                    }
                  },
                ),

                // Case transformation
                DropdownButton<CaseOption>(
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
                          .read(extractorStateProvider.notifier)
                          .setCaseOption(value);
                    }
                  },
                ),

                // Write mode
                DropdownButton<WriteMode>(
                  value: state.writeMode,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: [
                    for (final mode in WriteMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(
                          mode.displayName,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(extractorStateProvider.notifier)
                          .setWriteMode(value);
                    }
                  },
                ),

                // Replace underscores
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: state.replaceUnderscores,
                      onChanged: (value) {
                        ref
                            .read(extractorStateProvider.notifier)
                            .setReplaceUnderscores(value ?? false);
                      },
                    ),
                    const Text(
                      'Replace _ with space',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),

                // Trim whitespace
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: state.trimWhitespace,
                      onChanged: (value) {
                        ref
                            .read(extractorStateProvider.notifier)
                            .setTrimWhitespace(value ?? true);
                      },
                    ),
                    const Text(
                      'Trim whitespace',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Preview panel
            Expanded(
              child: ExtractorPreviewPanel(
                previews: state.previews,
                tokens: state.tokens,
                deselectedFiles: state.deselectedFiles,
                onToggleSelection: (filePath) {
                  ref
                      .read(extractorStateProvider.notifier)
                      .toggleFileSelection(filePath);
                },
              ),
            ),
          ],
        ),
      ),

      // 6. Actions
      actions: [
        TextButton(
          onPressed: state.isWriting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: state.isWriting ? null : _savePreset,
          child: const Text('Save Preset'),
        ),
        FilledButton(
          onPressed: state.isWriting || !hasMatches ? null : _writeTags,
          child: state.isWriting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Write Tags'),
        ),
      ],
    );
  }
}
