import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../online_lookup/presentation/widgets/lookup_dialog.dart';
import '../../../renamer/presentation/widgets/rename_dialog.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../data/providers/editor_state_provider.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/recent_folders_provider.dart';
import '../../data/providers/service_providers.dart';
import 'address_bar.dart';

/// Main toolbar with common actions.
class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  Future<void> _openFolder(WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Music Folder',
    );
    if (result == null) return;

    await _loadFromPath(ref, result);
  }

  Future<void> _openFiles(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Audio Files',
      type: FileType.custom,
      allowedExtensions: [
        'mp3', 'flac', 'ogg', 'm4a', 'mp4', 'wma', 'wav', 'ape', 'opus',
        'aac',
      ],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();

    final reader = ref.read(tagReaderProvider);
    final notifier = ref.read(fileListProvider.notifier);
    final statusNotifier = ref.read(statusMessageProvider.notifier);

    statusNotifier.state = 'Loading ${paths.length} file(s)...';
    final files = await reader.readTagsBatch(paths);
    notifier.addFiles(files);
    statusNotifier.state = 'Loaded ${files.length} file(s)';
  }

  Future<void> _loadFromPath(WidgetRef ref, String path) async {
    final reader = ref.read(tagReaderProvider);
    final notifier = ref.read(fileListProvider.notifier);
    final statusNotifier = ref.read(statusMessageProvider.notifier);

    statusNotifier.state = 'Scanning folder...';
    final audioFiles = await FileUtils.listAudioFiles(path);

    if (audioFiles.isEmpty) {
      statusNotifier.state = 'No supported audio files found in folder';
      return;
    }

    statusNotifier.state = 'Loading ${audioFiles.length} file(s)...';
    final paths = audioFiles.map((f) => f.path).toList();
    final files = await reader.readTagsBatch(paths);
    notifier.addFiles(files);

    // Update address bar and recent folders
    ref.read(loadedFolderPathProvider.notifier).state = path;
    ref.read(recentFoldersProvider.notifier).addFolder(path);

    statusNotifier.state = 'Loaded ${files.length} file(s)';
  }

  Future<void> _saveChanges(WidgetRef ref, BuildContext context) async {
    final files = ref.read(fileListProvider);
    final writer = ref.read(tagWriterProvider);
    final notifier = ref.read(fileListProvider.notifier);
    final statusNotifier = ref.read(statusMessageProvider.notifier);

    final modifiedFiles = files.where((f) => f.isModified).toList();
    if (modifiedFiles.isEmpty) {
      statusNotifier.state = 'No changes to save';
      return;
    }

    statusNotifier.state = 'Saving ${modifiedFiles.length} file(s)...';

    final fileTagsMap = <String, Map<String, String>>{};
    for (final file in modifiedFiles) {
      fileTagsMap[file.path] = file.tags;
    }

    final results = await writer.writeTagsBatch(fileTagsMap);
    final successCount = results.where((r) => r.success).length;
    final failCount = results.where((r) => !r.success).length;

    // Mark successful files as no longer modified
    final updatedFiles = modifiedFiles
        .where((f) => results.any((r) => r.path == f.path && r.success))
        .map((f) => f.copyWith(isModified: false))
        .toList();
    notifier.updateFiles(updatedFiles);

    if (failCount > 0) {
      statusNotifier.state =
          'Saved $successCount file(s), $failCount failed';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failCount file(s) failed to save'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
      statusNotifier.state = 'Saved $successCount file(s)';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final undoState = ref.watch(undoRedoProvider);
    final hasUnsaved = ref.watch(hasUnsavedChangesProvider);

    return Container(
      height: 48,
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
            onPressed: () => _openFolder(ref),
          ),
          _ToolbarButton(
            icon: Icons.audio_file,
            tooltip: 'Open Files',
            onPressed: () => _openFiles(ref),
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
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const RenameDialog(),
              );
            },
          ),
          _ToolbarButton(
            icon: Icons.search,
            tooltip: 'Online Lookup',
            onPressed: () {
              showLookupDialog(context, ref);
            },
          ),
          _ToolbarButton(
            icon: Icons.image,
            tooltip: 'Album Art',
            onPressed: () {
              // TODO: Open album art manager
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
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
