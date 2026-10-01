import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../features/album_art/data/cover_art_resize_service.dart';
import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/folder_panel/data/folder_panel_state_notifier.dart';
import '../../../../features/tools/data/clear_tags_command.dart';
import '../../../../features/tools/data/replay_gain.dart';
import '../../../../features/tools/data/strip_id3v1_command.dart';
import '../../../../features/tools/data/tag_case_tools.dart';
import '../../../../features/tools/data/tag_deletion_plan.dart';
import '../../../../features/tools/data/tag_transform_command.dart';
import '../../../../features/tools/presentation/clear_fields_dialog.dart';
import '../../../../features/tools/presentation/tag_sync_dialog.dart';
import '../../../../shared/models/audio_file.dart';
import '../../../../shared/services/export_service.dart';
import '../../../../shared/services/playlist_service.dart';
import '../../../../shared/widgets/save_flow.dart';
import '../../../extractor/presentation/widgets/extractor_dialog.dart';
import '../../../online_lookup/presentation/widgets/lookup_dialog.dart';
import '../../../renamer/presentation/widgets/rename_dialog.dart';
import '../../../settings/presentation/pages/settings_page.dart'
    show SettingsDialog;
import '../../data/providers/column_config_provider.dart';
import '../../data/providers/editor_state_provider.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../data/providers/service_providers.dart';
import '../../data/services/editor_open_service.dart';
import '../widgets/address_bar.dart';

/// Main toolbar with common actions.
class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  Future<void> _openFolder(WidgetRef ref, BuildContext context) =>
      EditorOpenService(ref.read).openFolder(context, ref);

  Future<void> _openFiles(WidgetRef ref, BuildContext context) =>
      EditorOpenService(ref.read).openFiles(context, ref);

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Playlist export failed: $e')));
      }
    }
  }

  Future<void> _exportData(WidgetRef ref, BuildContext context) async {
    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Export File Information',
      fileName: 'tags.csv',
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'html', 'htm'],
    );
    if (outputPath == null || outputPath.isEmpty) return;

    try {
      final files = ref.read(filteredSortedFileListProvider);
      final config = ref.read(columnConfigProvider);
      final columns = ExportService.columnsFor(config.visibleColumnIds.toSet());
      final content = ExportService.serializeFor(outputPath, files, columns);
      if (content is Uint8List) {
        await File(outputPath).writeAsBytes(content);
      } else {
        await File(outputPath).writeAsString(content as String);
      }

      ref.read(statusMessageProvider.notifier).state =
          'Exported ${files.length} file(s) to ${outputPath.split(Platform.pathSeparator).last}';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${files.length} row(s)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _saveChanges(WidgetRef ref, BuildContext context) async {
    await SaveFlow.saveAll(context, ref);
  }

  /// Opens the cover-art resize/convert dialog and runs the batch with
  /// progress feedback.
  Future<void> _showResizeCoverArtDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selected = ref.read(selectedFilesProvider);
    final withArt = selected.where((f) => f.albumArt != null).toList();
    if (withArt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected files have no embedded cover art to resize.'),
        ),
      );
      return;
    }

    var maxDimension = 500;
    var format = CoverArtFormat.keep;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Resize / Convert Cover Art'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${withArt.length} file(s) with embedded art will be '
                'resized in place. Originals are recoverable via Undo.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: maxDimension,
                decoration: const InputDecoration(
                  labelText: 'Max dimension (longest side, px)',
                  isDense: true,
                ),
                items: const [200, 300, 500, 800, 1000]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: (v) => setDialogState(() => maxDimension = v ?? 500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<CoverArtFormat>(
                initialValue: format,
                decoration: const InputDecoration(
                  labelText: 'Output format',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: CoverArtFormat.keep,
                    child: Text('Keep current'),
                  ),
                  DropdownMenuItem(
                    value: CoverArtFormat.jpeg,
                    child: Text('JPEG'),
                  ),
                  DropdownMenuItem(
                    value: CoverArtFormat.png,
                    child: Text('PNG'),
                  ),
                ],
                onChanged: (v) => setDialogState(() => format = v ?? format),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Resize'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final status = ref.read(statusMessageProvider.notifier);
    final service = CoverArtResizeService(
      tagWriter: ref.read(tagWriterProvider),
      fileListNotifier: ref.read(fileListProvider.notifier),
      undoRedoManager: ref.read(undoRedoProvider.notifier),
    );
    final options = CoverArtResizeOptions(
      maxDimension: maxDimension,
      format: format,
    );

    await for (final progress in service.resizeAlbumArt(withArt, options)) {
      status.state =
          'Resizing cover art ${progress.completed}/${progress.total}...';
    }

    status.state = 'Cover art resized ($maxDimension px)';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cover art resized on ${withArt.length} file(s)'),
        ),
      );
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

      ref
          .read(undoRedoProvider.notifier)
          .execute(
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

    if (value == 'art:resize') {
      _showResizeCoverArtDialog(context, ref);
      return;
    }

    if (value == 'sync:wizard') {
      if (ref.read(selectedFilesProvider).isEmpty) {
        status.state = 'Select MP3 files to synchronize';
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => const TagSyncDialog(),
      );
      return;
    }

    if (value == 'tags:clearAll') {
      await _clearAllTags(context, ref);
      return;
    }

    if (value == 'tags:clearFields') {
      await _clearFields(context, ref);
      return;
    }

    if (value == 'tags:stripId3v1') {
      await _stripId3v1(context, ref);
      return;
    }

    if (value == 'tags:clearReplayGain') {
      await _clearReplayGain(context, ref);
      return;
    }
  }

  /// "Clear ReplayGain..." — removes only the four ReplayGain fields, so an
  /// external scanner (loudgain, foobar2000, mp3gain) can recalculate them.
  Future<void> _clearReplayGain(BuildContext context, WidgetRef ref) async {
    final targets = _targetFiles(ref);
    if (targets.isEmpty) {
      _setStatus(ref, 'No files loaded');
      return;
    }

    // Only the fields actually present can be cleared; clearing a field that
    // is already absent would show up as a phantom modification.
    final plan = planClear(
      targets,
      ReplayGainField.values.map((f) => f.appField).toSet(),
    );
    if (plan.isEmpty) {
      _setStatus(ref, 'No ReplayGain data in the selection');
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear ReplayGain'),
        content: Text(
          'Remove ${plan.fieldCount} ReplayGain value(s) from '
          '${plan.affectedFileCount} of ${plan.fileCount} file(s)?\n\n'
          'This is undoable, and only written to disk when you save. All '
          'other tags are left untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    ref
        .read(undoRedoProvider.notifier)
        .execute(
          ClearTagsCommand(
            fileListNotifier: ref.read(fileListProvider.notifier),
            plan: plan,
            description: 'Clear ReplayGain (${plan.affectedFileCount} file(s))',
          ),
        );
    _setStatus(
      ref,
      'Cleared ${plan.fieldCount} ReplayGain value(s) in '
      '${plan.affectedFileCount} file(s) - unsaved',
    );
  }

  /// Targets for a tag-removal action: the current selection, or every
  /// loaded file when nothing is selected.
  List<AudioFile> _targetFiles(WidgetRef ref) {
    final selected = ref.read(selectedFilesProvider);
    return selected.isNotEmpty ? selected : ref.read(fileListProvider);
  }

  /// "Clear All Tags" — removes every field the app manages from the
  /// targets, after an explicit confirmation that states the real counts.
  Future<void> _clearAllTags(BuildContext context, WidgetRef ref) async {
    final targets = _targetFiles(ref);
    if (targets.isEmpty) {
      _setStatus(ref, 'No files loaded');
      return;
    }

    final plan = planClear(targets, null);
    if (plan.isEmpty) {
      _setStatus(ref, 'No tag fields to clear');
      return;
    }

    if (!context.mounted) return;
    // ReplayGain is calculated data a user may have gone to real trouble to
    // acquire, so the confirmation names it explicitly rather than hiding
    // it behind "all metadata".
    final rgFields = ReplayGainField.values.map((f) => f.appField).toSet();
    final rgCount = plan.fieldsToClearByPath.values.fold<int>(
      0,
      (sum, fields) => sum + fields.where(rgFields.contains).length,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Tags'),
        content: Text(
          'Remove ${plan.fieldCount} tag field(s) from '
          '${plan.affectedFileCount} of ${plan.fileCount} file(s)?\n\n'
          'This is undoable, and is only written to disk when you save.'
          '${rgCount > 0 ? '\n\n$rgCount of these are ReplayGain loudness values; use "Clear Fields..." to keep them.' : ''}\n\n'
          'Frames the editor does not manage (for example custom ID3v2 '
          'frames) are left in place.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear Tags'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    ref
        .read(undoRedoProvider.notifier)
        .execute(
          ClearTagsCommand(
            fileListNotifier: ref.read(fileListProvider.notifier),
            plan: plan,
            description: 'Clear all tags (${plan.affectedFileCount} file(s))',
          ),
        );
    _setStatus(
      ref,
      'Cleared ${plan.fieldCount} field(s) in '
      '${plan.affectedFileCount} file(s) - unsaved',
    );
  }

  /// "Clear Fields..." — lets the user pick which fields to remove.
  Future<void> _clearFields(BuildContext context, WidgetRef ref) async {
    final targets = _targetFiles(ref);
    if (targets.isEmpty) {
      _setStatus(ref, 'No files loaded');
      return;
    }

    if (!context.mounted) return;
    final fields = await ClearFieldsDialog.show(context, files: targets);
    if (fields == null || fields.isEmpty) return;

    final plan = planClear(targets, fields);
    if (plan.isEmpty) {
      _setStatus(ref, 'Nothing to clear in the selection');
      return;
    }

    ref
        .read(undoRedoProvider.notifier)
        .execute(
          ClearTagsCommand(
            fileListNotifier: ref.read(fileListProvider.notifier),
            plan: plan,
            description:
                'Clear ${plan.fieldCount} field(s) '
                '(${plan.affectedFileCount} file(s))',
          ),
        );
    _setStatus(
      ref,
      'Cleared ${plan.fieldCount} field(s) in '
      '${plan.affectedFileCount} file(s) - unsaved',
    );
  }

  /// "Remove ID3v1 Tag" — deletes the trailing ID3v1 block from MP3s.
  ///
  /// This one writes to disk immediately: an ID3v1 trailer is not reachable
  /// through TagLib's Properties API, so it cannot ride the normal save path.
  Future<void> _stripId3v1(BuildContext context, WidgetRef ref) async {
    final targets = _targetFiles(ref);
    if (targets.isEmpty) {
      _setStatus(ref, 'No files loaded');
      return;
    }

    final command = StripId3v1Command.planFor(targets);
    if (command == null) {
      _setStatus(ref, 'No ID3v1 tags found in the selection');
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove ID3v1 Tag'),
        content: Text(
          'Delete the ID3v1 block from ${command.files.length} MP3 file(s)?\n\n'
          'ID3v2 and other tags are preserved. This is undoable, and writes '
          'to disk immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    ref.read(undoRedoProvider.notifier).execute(command);

    final summary =
        '${command.files.length} file(s) processed, '
        '${command.previousTags.length} ID3v1 tag(s) removed';
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(summary)));
    }
    _setStatus(ref, summary);
  }

  void _setStatus(WidgetRef ref, String message) {
    ref.read(statusMessageProvider.notifier).state = message;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final undoState = ref.watch(undoRedoProvider);
    final hasUnsaved = ref.watch(hasUnsavedChangesProvider);
    final errorCount = ref.watch(errorCountProvider);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
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
                  child: Text(
                    tool.menuLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'art:resize',
                child: Text(
                  'Resize / Convert Cover Art...',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sync:wizard',
                child: Text(
                  'Tags Synchronization…',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'tags:clearAll',
                enabled: ref.read(fileListProvider).isNotEmpty,
                child: const Text(
                  'Clear All Tags…',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              PopupMenuItem(
                value: 'tags:clearFields',
                enabled: ref.read(fileListProvider).isNotEmpty,
                child: const Text(
                  'Clear Fields…',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              PopupMenuItem(
                value: 'tags:stripId3v1',
                enabled: ref.read(fileListProvider).isNotEmpty,
                child: const Text(
                  // Ellipsis, like its sibling destructive actions: this one
                  // opens a confirmation dialog and the ellipsis is the only
                  // thing that signals that.
                  'Remove ID3v1 Tag…',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              PopupMenuItem(
                value: 'tags:clearReplayGain',
                enabled: ref.read(fileListProvider).isNotEmpty,
                child: const Text(
                  'Clear ReplayGain…',
                  style: TextStyle(fontSize: 12),
                ),
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
          // Persistent entry point to the error panel. The status bar already
          // toggles it on click, but it only renders when there are errors,
          // so a user with the panel closed had no way to find it again
          // without producing a new error. This shows the count inline so
          // the panel is always reachable.
          _ToolbarButton(
            icon: Icons.report_gmailerrorred,
            tooltip:
                'Error Log ($errorCount error${errorCount == 1 ? '' : 's'})',
            onPressed: () {
              final notifier = ref.read(errorPanelVisibleProvider.notifier);
              notifier.state = !notifier.state;
            },
          ),
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
    // No explicit Semantics needed: IconButton promotes `tooltip` to the
    // button's accessible name and drops the icon from the tree, so the
    // button already has exactly one name.
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}
