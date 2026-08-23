import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../folder_panel/presentation/breadcrumb_bar.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../data/providers/folder_loading_provider.dart';
import '../../data/providers/grid_items_provider.dart';
import '../../data/providers/selection_provider.dart';
import '../helpers/grid_navigation.dart';
import 'data_grid/data_grid.dart';

/// Panel showing the list of loaded audio files with address bar,
/// data grid, filter controls, and status bar.
class FileListPanel extends ConsumerWidget {
  const FileListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          final gridItems = ref.read(gridItemsProvider);
          ref
              .read(selectionProvider.notifier)
              .selectAll(filePathsFromGridItems(gridItems));
        },
      },
      child: Focus(
        autofocus: true,
        child: ClipRect(
          child: Column(
            children: [
            // Breadcrumb bar with folder path navigation
            BreadcrumbBar(
              onFolderSelected: (path) async {
                // Guard against unsaved changes before loading a new folder.
                final proceed = await UnsavedChangesGuard.check(
                  context: context,
                  ref: ref,
                  clearUndoOnDiscard: true,
                );
                if (!proceed) return;
                if (!context.mounted) return;
                final service = FolderLoadingService(ref.read);
                await service.loadFolder(context, path);
              },
            ),
            // Filter bar with text filter and show-selected toggle
            _FilterBar(),
            // Data grid (column headers + virtualized rows)
            const Expanded(child: DataGrid()),
          ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  final _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSelectedOnly = ref.watch(showSelectedOnlyProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Text filter
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _filterController,
                decoration: InputDecoration(
                  hintText: 'Filter files...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _filterController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _filterController.clear();
                            ref.read(fileFilterProvider.notifier).state = '';
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (value) {
                  ref.read(fileFilterProvider.notifier).state = value;
                },
              ),
            ),
          ),
          if (showSelectedOnly) ...[
            const SizedBox(width: 8),
            Chip(
              label: const Text(
                'Showing selected only',
                style: TextStyle(fontSize: 11),
              ),
              onDeleted: () {
                ref.read(showSelectedOnlyProvider.notifier).state = false;
              },
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
          const SizedBox(width: 8),
          // Show selected only toggle
          Tooltip(
            message: 'Show selected files only',
            child: IconButton(
              icon: Icon(
                showSelectedOnly
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                size: 18,
                color: showSelectedOnly
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: () {
                ref.read(showSelectedOnlyProvider.notifier).state =
                    !showSelectedOnly;
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
