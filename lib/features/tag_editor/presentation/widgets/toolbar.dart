import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/error_handling/utils/error_entry_factory.dart';
import '../../../../features/folder_panel/data/folder_panel_state_notifier.dart';
import '../../../../features/tools/data/tag_case_tools.dart';
import '../../../../features/tools/data/tag_transform_command.dart';
import '../../../../shared/services/export_service.dart';
import '../../../../shared/services/playlist_service.dart';
import '../../../../shared/services/tag_sync_service.dart';
import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../extractor/presentation/widgets/extractor_dialog.dart';
import '../../../online_lookup/presentation/widgets/lookup_dialog.dart';
import '../../../renamer/presentation/widgets/rename_dialog.dart';
import '../../../settings/presentation/pages/settings_page.dart'
    show SettingsDialog;
import '../../data/providers/column_config_provider.dart';
import '../../data/providers/editor_state_provider.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../data/providers/folder_loading_provider.dart';
import '../../data/providers/service_providers.dart';
import '../widgets/address_bar.dart';

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

  Future<void> _exportPlaylist(WidgetRef ref, BuildContext context) async {
    final allFiles = ref.read(fileListProvider);
    final selected = ref.read(selectedFilesProvider);
    final files = selected.isNotEmpty ? selected : allFiles;
    if (files.isEmpty) return;

    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Export Playlist',
      fileName: 'playlist.m3u8',
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8'],
    );
    if (outputPath == null || outputPath.isEmpty) return;

    try {
      final baseDir = ref.read(loadedFolderPathProvider);
      // Relative to loaded folder for portability, matching Tag&Rename.
      await PlaylistService.writePlaylistFile(
        outputPath,
        files,
        extended: true,
        useAbsolutePaths: false,
        baseDirectory: baseDir,
      );
      if (!context.mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist exported (${files.length} tracks)')),
        );
      }
      ref.read(statusMessageProvider.notifier).state =
          'Exported playlist (${files.length} tracks)';
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportData(WidgetRef ref, BuildContext context) async {
    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Export File Information',
      fileName: 'tags.csv',
      type: FileType.custom,
      allowedExtensions: ['csv', 'html', 'htm'],
    );
    if (outputPath == null || outputPath.isEmpty) return;

    try {
      final files = ref.read(filteredSortedFileListProvider);
      final config = ref.read(columnConfigProvider);
      final columns = ExportService.columnsFor(
        config.visibleColumnIds.toSet(),
      );
      final content = ExportService.serializeFor(outputPath, files, columns);
      await File(outputPath).writeAsString(content);

      ref.read(statusMessageProvider.notifier).state =
          'Exported ${files.length} file(s) to ${outputPath.split(Platform.pathSeparator).last}';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${files.length} row(s)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
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

  /// Dispatches Tools-menu actions: per-file tag transforms (undoable)
  /// and ID3v1<->v2 synchronization (disk writes via TagSyncService).
  Future<void> _onToolSelected(
    String value,
    WidgetRef ref,
    BuildContext context,
  ) async {
    final status = ref.read(statusMessageProvider.notifier);
    final selected = ref.read(selectedFilesProvider);

    if (value.startsWith('tool:')) {
      final tool = TagTool.values.firstWhere((t) => 'tool:${t.name}' == value);

      // Build per-file deltas from the tool transform.
      final deltas = <String, Map<String, String>>{};
      final previousTags = <String, Map<String, String>>{};
      for (final file in selected) {
        final delta = applyTool(tool, file);
        if (delta.isEmpty) continue;
        deltas[file.path] = delta;
        previousTags[file.path] = Map.of(file.tags);
      }

      if (deltas.isEmpty) {
        status.state = 'Nothing to change';
        return;
      }

      ref.read(undoRedoProvider.notifier).execute(
            TagTransformCommand(
              fileListNotifier: ref.read(fileListProvider.notifier),
              deltas: deltas,
              previousTags: previousTags,
              description: '${tool.menuLabel} (${deltas.length} file(s))',
            ),
          );
      status.state = '${tool.menuLabel}: ${deltas.length} file(s) changed';
      return;
    }

    if (value.startsWith('sync:')) {
      final direction = value.split(':')[1];
      final service = TagSyncService(tagWriter: ref.read(tagWriterProvider));
      status.state = 'Synchronizing tags...';

      final result = direction == 'v2toV1'
          ? await service.syncToId3v1(selected)
          : await service.syncFromId3v1(selected);

      status.state = 'Tag sync: ${result.updatedCount} updated, '
          '${result.skippedCount} skipped';

      if (result.failures.isNotEmpty) {
        ref.read(errorLogProvider.notifier).addEntries([
          for (final f in result.failures)
            ErrorEntryFactory.fromLookupFailure(
              summary: f.path,
              message: f.error ?? 'Unknown sync error',
            ),
        ]);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.failures.length} file(s) failed to sync'),
              action: SnackBarAction(
                label: 'Details',
                onPressed: () =>
                    ref.read(errorPanelVisibleProvider.notifier).state = true,
              ),
            ),
          );
        }
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
            icon: Icons.playlist_add,
            tooltip: 'Export Playlist',
            onPressed: ref.watch(fileListProvider).isEmpty
                ? null
                : () => _exportPlaylist(ref, context),
          ),
          _ToolbarButton(
            icon: Icons.table_view,
            tooltip: 'Export File Information (CSV / HTML)',
            onPressed: ref.watch(fileListProvider).isEmpty
                ? null
                : () => _exportData(ref, context),
          ),
          // Tools menu: batch tag utilities (Tag&Rename parity).
          PopupMenuButton<String>(
            tooltip: 'Tools',
            icon: const Icon(Icons.handyman, size: 20),
            onSelected: (value) => _onToolSelected(value, ref, context),
            itemBuilder: (context) => [
              for (final tool in TagTool.values)
                PopupMenuItem(
                  value: 'tool:${tool.name}',
                  enabled: ref.read(selectedFilesProvider).isNotEmpty,
                  child: Text(tool.menuLabel,
                      style: const TextStyle(fontSize: 12)),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sync:v2toV1',
                child:
                    Text('Sync tags to ID3v1', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem(
                value: 'sync:v1toV2',
                child: Text('Fill empty tags from ID3v1',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
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
