import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _handleDrop(List<String> paths) async {
    if (!mounted) return;
    final service = FolderLoadingService(ref);
    await service.loadFromDrop(context, paths);
  }

  @override
  Widget build(BuildContext context) {
    final isTagPanelOpen = ref.watch(tagPanelOpenProvider);

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
                  child: Row(
                    children: [
                      // File list panel (takes full width when tag panel closed)
                      const Expanded(
                        child: FileListPanel(),
                      ),
                      // Tag editor side panel (collapsible)
                      if (isTagPanelOpen) ...[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 380,
                          child: Column(
                            children: [
                              // Panel header with close button
                              Container(
                                height: 36,
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
                        ),
                      ],
                    ],
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
}
