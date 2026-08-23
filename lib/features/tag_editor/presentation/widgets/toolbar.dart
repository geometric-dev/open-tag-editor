import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/error_handling/utils/error_entry_factory.dart';
import '../../../../features/folder_panel/data/folder_panel_state_notifier.dart';
import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../extractor/presentation/widgets/extractor_dialog.dart';
import '../../../online_lookup/presentation/widgets/lookup_dialog.dart';
import '../../../renamer/presentation/widgets/rename_dialog.dart';
import '../../../settings/presentation/pages/settings_page.dart'
    show SettingsDialog;
import '../../data/providers/editor_state_provider.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/folder_loading_provider.dart';
import '../../data/providers/service_providers.dart';

/// Main toolbar with common actions.
class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  Future<void> _openFolder(WidgetRef ref, BuildContext context) async {
    // Guard against unsaved changes before opening a new folder.
    if (context.mounted) {
      final proceed = await UnsavedChangesGuard.check(
        context: context,
        ref: ref,
        clearUndoOnDiscard: true,
      );
      if (!proceed) return;
    }

    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Music Folder',
    );
    if (result == null) return;

    // Route through the shared loading service so the toolbar honours the
    // recursive toggle, the threshold guard, and recent-folder persistence
    // exactly like every other entry point.
    final service = FolderLoadingService(ref.read);
    await service.loadFolder(context, result);
  }

  Future<void> _openFiles(WidgetRef ref, BuildContext context) async {
    // Guard against unsaved changes before opening new files.
    if (context.mounted) {
      final proceed = await UnsavedChangesGuard.check(
        context: context,
        ref: ref,
        clearUndoOnDiscard: true,
      );
      if (!proceed) return;
    }

    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select Audio Files',
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'flac',
        'ogg',
        'm4a',
        'mp4',
        'wma',
        'wav',
        'ape',
        'opus',
        'aac',
      ],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final paths =
        result.files.where((f) => f.path != null).map((f) => f.path!).toList();

    final service = FolderLoadingService(ref.read);
    await service.loadFromDrop(context, paths);
  }

  Future<void> _saveChanges(WidgetRef ref, BuildContext context) async {
    final statusNotifier = ref.read(statusMessageProvider.notifier);

    statusNotifier.state = 'Saving...';

    final summary = await ref.read(tagSaveServiceProvider).saveAllModified();

    if (summary == null) {
      statusNotifier.state = 'No changes to save';
      return;
    }

    if (!summary.allSuccess) {
      // Report failures to error log
      final entries = ErrorEntryFactory.fromWriteResults(
        summary.results,
        summary.attemptedTags,
      );
      ref.read(errorLogProvider.notifier).addEntries(entries);
      statusNotifier.state =
          'Saved ${summary.successCount} file(s), ${summary.failureCount} failed';
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${summary.failureCount} file(s) failed to save'),
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
      }
    } else {
      statusNotifier.state = 'Saved ${summary.successCount} file(s)';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${summary.successCount} file(s) saved successfully'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final undoState = ref.watch(undoRedoProvider);
    final hasUnsaved = ref.watch(hasUnsavedChangesProvider);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.folder_open,
            tooltip: 'Open Folder',
            onPressed: () => _openFolder(ref, context),
          ),
          _ToolbarButton(
            icon: Icons.audio_file,
            tooltip: 'Open Files',
            onPressed: () => _openFiles(ref, context),
          ),
          _ToolbarButton(
            icon: Icons.view_sidebar,
            tooltip: 'Toggle Folder Panel',
            onPressed: () =>
                ref.read(folderPanelStateProvider.notifier).toggle(),
          ),
          const VerticalDivider(indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.save,
            tooltip: 'Save Changes (Ctrl+S)',
            onPressed: hasUnsaved ? () => _saveChanges(ref, context) : null,
          ),
          _ToolbarButton(
            icon: Icons.undo,
            tooltip: undoState.canUndo
                ? 'Undo: ${undoState.undoDescription} (Ctrl+Z)'
                : 'Undo (Ctrl+Z)',
            onPressed: undoState.canUndo
                ? () => ref.read(undoRedoProvider.notifier).undo()
                : null,
          ),
          _ToolbarButton(
            icon: Icons.redo,
            tooltip: undoState.canRedo
                ? 'Redo: ${undoState.redoDescription} (Ctrl+Y)'
                : 'Redo (Ctrl+Y)',
            onPressed: undoState.canRedo
                ? () => ref.read(undoRedoProvider.notifier).redo()
                : null,
          ),
          const VerticalDivider(indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.drive_file_rename_outline,
            tooltip: 'Rename Files',
            onPressed: ref.watch(fileListProvider).isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (_) => const RenameDialog(),
                    );
                  },
          ),
          _ToolbarButton(
            icon: Icons.text_snippet,
            tooltip: 'Tags from Filename',
            onPressed: ref.watch(fileListProvider).isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (_) => const ExtractorDialog(),
                    );
                  },
          ),
          _ToolbarButton(
            icon: Icons.search,
            tooltip: ref.watch(selectedFilesProvider).isEmpty
                ? 'Select files to look up metadata'
                : 'Online Lookup',
            onPressed: ref.watch(selectedFilesProvider).isEmpty
                ? null
                : () {
                    showLookupDialog(context, ref);
                  },
          ),
          _ToolbarButton(
            icon: Icons.image,
            tooltip: 'Album Art',
            onPressed: ref.watch(selectedFilesProvider).isEmpty
                ? null
                : () {
                    ref.read(tagPanelOpenProvider.notifier).state = true;
                    ref.read(tagPanelActiveTabProvider.notifier).state =
                        TagPanelTab.albumArt;
                  },
          ),
          _ToolbarButton(
            icon: Icons.edit_note,
            tooltip: 'Toggle Tag Editor Panel',
            onPressed: () {
              final current = ref.read(tagPanelOpenProvider);
              ref.read(tagPanelOpenProvider.notifier).state = !current;
            },
          ),
          const Spacer(),
          _ToolbarButton(
            icon: Icons.settings,
            tooltip: 'Settings',
            onPressed: () {
              SettingsDialog.show(context);
            },
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}
