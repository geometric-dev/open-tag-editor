import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/error_handling/widgets/error_panel.dart';
import '../../../../features/folder_panel/data/folder_panel_state_notifier.dart';
import '../../../../features/folder_panel/presentation/folder_panel.dart';
import '../../../../features/settings/data/providers/settings_providers.dart';
import '../../../../shared/widgets/resizable_splitter.dart';
import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../../shared/widgets/vertical_resizable_splitter.dart';
import '../../data/providers/editor_state_provider.dart';
import '../../data/providers/folder_loading_provider.dart';
import '../widgets/file_list_panel.dart';
import '../widgets/status_bar.dart';
import '../widgets/tag_edit_panel.dart';
import '../widgets/toolbar.dart';

/// The main application page with a split-pane layout:
/// - Left: file browser / file list
/// - Right: tag editor panel
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isDragging = false;
  double _errorPanelHeight = 200.0;

  Future<void> _handleDrop(List<String> paths) async {
    if (!mounted) return;

    // Guard against unsaved changes before loading dropped files.
    final proceed = await UnsavedChangesGuard.check(
      context: context,
      ref: ref,
      clearUndoOnDiscard: true,
    );
    if (!proceed) return;

    if (!mounted) return;
    final service = FolderLoadingService(ref.read);
    await service.loadFromDrop(context, paths);
  }

  Future<void> _handleFolderSelected(String path) async {
    if (!mounted) return;
    final proceed = await UnsavedChangesGuard.check(
      context: context,
      ref: ref,
      clearUndoOnDiscard: true,
    );
    if (!proceed) return;
    if (!mounted) return;
    final service = FolderLoadingService(ref.read);
    await service.loadFolder(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final isTagPanelOpen = ref.watch(tagPanelOpenProvider);
    final tagPanelWidth = ref.watch(
      windowStateProvider.select((s) => s.tagPanelWidth),
    );
    final isErrorPanelOpen = ref.watch(errorPanelVisibleProvider);
    final isFolderPanelVisible = ref.watch(folderPanelStateProvider);

    return Scaffold(
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          final paths = details.files.map((f) => f.path).toList();
          _handleDrop(paths);
        },
        child: Stack(
          children: [
            Column(
              children: [
                const EditorToolbar(),
                Expanded(
                  child: _buildMainContent(
                    isTagPanelOpen: isTagPanelOpen,
                    tagPanelWidth: tagPanelWidth,
                    isErrorPanelOpen: isErrorPanelOpen,
                    isFolderPanelVisible: isFolderPanelVisible,
                  ),
                ),
                // Enhanced status bar
                const EnhancedStatusBar(),
              ],
            ),
            // Drag overlay
            if (_isDragging)
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Drop audio files or folders here',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent({
    required bool isTagPanelOpen,
    required double tagPanelWidth,
    required bool isErrorPanelOpen,
    required bool isFolderPanelVisible,
  }) {
    final fileListContent = isTagPanelOpen
        ? ResizableSplitter(
            leftChild: const FileListPanel(),
            rightChild: Column(
              children: [
                // Panel header with close button
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Tag Editor',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => ref
                            .read(tagPanelOpenProvider.notifier)
                            .state = false,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Close Tag Editor',
                      ),
                    ],
                  ),
                ),
                const Expanded(child: TagEditPanel()),
              ],
            ),
            rightWidth: tagPanelWidth,
            minRightWidth: 280.0,
            maxRightWidthFraction: 0.5,
            onWidthChanged: (width) {
              ref
                  .read(windowStateProvider.notifier)
                  .setTagPanelWidth(width);
            },
            onDragEnd: () {
              // Persistence is already handled in
              // setTagPanelWidth via the notifier.
            },
          )
        : const Row(
            children: [
              Expanded(child: FileListPanel()),
            ],
          );

    final content = Row(
      children: [
        if (isFolderPanelVisible)
          FolderPanel(onFolderSelected: _handleFolderSelected),
        Expanded(child: fileListContent),
      ],
    );

    if (!isErrorPanelOpen) {
      return content;
    }

    return VerticalResizableSplitter(
      topChild: content,
      bottomChild: const ErrorPanel(),
      bottomHeight: _errorPanelHeight,
      onHeightChanged: (h) => setState(() => _errorPanelHeight = h),
    );
  }
}
