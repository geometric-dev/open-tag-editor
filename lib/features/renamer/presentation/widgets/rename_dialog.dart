import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/file_utils.dart';
import '../../../../shared/models/audio_file.dart';
import '../../../../shared/models/rename_result.dart';
import '../../../error_handling/providers/error_providers.dart';
import '../../../error_handling/utils/error_entry_factory.dart';
import '../../../settings/data/providers/settings_providers.dart';
import '../../../tag_editor/data/providers/file_list_provider.dart';
import '../../../tag_editor/data/providers/selection_provider.dart';
import '../../../tag_editor/data/providers/service_providers.dart';
import '../../../tag_editor/presentation/widgets/address_bar.dart';
import '../../data/models/case_option.dart';
import '../../data/models/conflict_strategy.dart';
import '../../data/models/rename_execution_result.dart';
import '../../data/models/rename_preview.dart';
import '../../data/models/tag_variable.dart';
import '../../data/providers/renamer_providers.dart';
import '../../data/rename_scope.dart';
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

    final okPreviews = state.previews
        .where((p) => p.status == RenamePreviewStatus.ok)
        .toList();
    final okPaths = okPreviews.map((p) => p.originalPath).toSet();
    final files = notifier.files;
    final readOnlyFiles = files
        .where(
          (f) =>
              okPaths.contains(f.path) &&
              (f.isReadOnly || FileUtils.isFileReadOnly(File(f.path))),
        )
        .toList();

    var skipReadOnly = false;
    var ignoreReadOnly = false;

    if (readOnlyFiles.isNotEmpty) {
      final action = await _showReadOnlyWarningDialog(context, readOnlyFiles);
      if (action == null || action == _ReadOnlyAction.cancel) {
        // Cancel returns to preview
        return;
      } else if (action == _ReadOnlyAction.skip) {
        skipReadOnly = true;
      } else if (action == _ReadOnlyAction.rename) {
        ignoreReadOnly = true;
      }
    }

    final skipPaths = skipReadOnly
        ? readOnlyFiles.map((f) => f.path).toSet()
        : null;

    final result = await notifier.executeRename(
      skipPaths: skipPaths,
      ignoreReadOnly: ignoreReadOnly,
    );

    // 1b) Partially refresh the file list for the updated files.
    if (result.successfulRenames.isNotEmpty) {
      // A rename can move a file out of the folder currently loaded in the
      // grid. Those files no longer belong to the loaded scope, so they are
      // dropped from the list rather than shown under a nonsense `../..`
      // breadcrumb. Files that stayed inside the root are updated in place.
      final root = ref.read(loadedFolderPathProvider);
      final scope = partitionRenamesByScope(result.successfulRenames, root);

      if (scope.insideRoot.isNotEmpty) {
        ref.read(fileListProvider.notifier).applyRenames(scope.insideRoot);
        ref.read(selectionProvider.notifier).remapPaths(scope.insideRoot);

        // Refresh tags for the newly renamed files so in-memory tags are fresh.
        final tagReader = ref.read(tagReaderProvider);
        final refreshed = await tagReader.readTagsBatch(
          scope.insideRoot.values.toList(),
        );
        ref.read(fileListProvider.notifier).updateFiles(refreshed);
      }

      if (scope.outsideRoot.isNotEmpty) {
        final movedOutPaths = scope.outsideRoot.keys.toSet();
        ref.read(fileListProvider.notifier).removeFiles(movedOutPaths);
        ref.read(selectionProvider.notifier).removePaths(movedOutPaths);
      }
    }

    if (mounted) {
      if (result.errorCount > 0) {
        // Flag failed files with error messages in the file list
        final errorsByPath = {
          for (final e in result.errors)
            e.filePath: 'Rename failed: ${e.message}',
        };
        ref.read(fileListProvider.notifier).setFileErrors(errorsByPath);

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

        // Show persistent Rename Failure Alert Dialog (not relying on toast)
        await _showRenameFailureDialog(context, result);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showRenameFailureDialog(
    BuildContext context,
    RenameExecutionResult result,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 22),
              const SizedBox(width: 8),
              const Text('Rename Incomplete'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.errorCount} of ${result.totalCount} file(s) could not be renamed.\n'
                  '${result.renamedCount} file(s) were successfully renamed.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: result.errors.length,
                    itemBuilder: (context, index) {
                      final err = result.errors[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              err.filePath,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              err.message,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Unrenamed files have been flagged in the list with an error indicator.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(errorPanelVisibleProvider.notifier).state = true;
                Navigator.of(context).pop();
              },
              child: const Text('View Error Log'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<_ReadOnlyAction?> _showReadOnlyWarningDialog(
    BuildContext context,
    List<AudioFile> readOnlyFiles,
  ) {
    final count = readOnlyFiles.length;
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<_ReadOnlyAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: colorScheme.error, size: 22),
              const SizedBox(width: 8),
              Text(count == 1 ? 'Read-Only File' : 'Read-Only Files'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? 'The following file is marked as read-only on the filesystem:'
                      : '$count selected files are marked as read-only on the filesystem:',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: readOnlyFiles.length,
                    itemBuilder: (context, index) {
                      final f = readOnlyFiles[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                f.filename,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cancel returns to preview. Skip will skip these read-only files. Rename will proceed and rename them anyway.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_ReadOnlyAction.cancel),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(_ReadOnlyAction.skip),
              child: Text(count == 1 ? 'Skip' : 'Skip ($count)'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_ReadOnlyAction.rename),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
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

enum _ReadOnlyAction { cancel, skip, rename }
