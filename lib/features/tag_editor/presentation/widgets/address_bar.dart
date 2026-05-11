import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/recent_folders_provider.dart';
import '../../data/providers/recursive_loading_provider.dart';

/// Provider for the currently loaded folder path.
final loadedFolderPathProvider = StateProvider<String?>((ref) => null);

/// Address bar showing the loaded folder path with recent folders and recursive toggle.
///
/// The path is editable — users can paste or type a folder path and press Enter
/// to load it.
class AddressBar extends ConsumerStatefulWidget {
  const AddressBar({
    super.key,
    this.onFolderSelected,
  });

  /// Callback when a folder path is submitted (typed/pasted + Enter, or selected
  /// from recent folders).
  final void Function(String path)? onFolderSelected;

  @override
  ConsumerState<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends ConsumerState<AddressBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    final currentPath = ref.read(loadedFolderPathProvider) ?? '';
    _controller.text = currentPath;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: currentPath.length,
    );
    setState(() => _isEditing = true);
    _focusNode.requestFocus();
  }

  void _submitPath() {
    final path = _controller.text.trim();
    setState(() => _isEditing = false);
    if (path.isNotEmpty) {
      widget.onFolderSelected?.call(path);
    }
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final folderPath = ref.watch(loadedFolderPathProvider);
    final recentFolders = ref.watch(recentFoldersProvider);
    final isRecursive = ref.watch(recursiveLoadingProvider);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          // Folder icon
          const Icon(Icons.folder_outlined, size: 16),
          const SizedBox(width: 8),
          // Editable path field
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      hintText: 'Enter folder path...',
                    ),
                    onSubmitted: (_) => _submitPath(),
                    onTapOutside: (_) => _cancelEditing(),
                  )
                : GestureDetector(
                    onTap: _startEditing,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        folderPath ?? 'Click to enter folder path...',
                        style: TextStyle(
                          fontSize: 12,
                          color: folderPath != null
                              ? null
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),
          // Recent folders dropdown
          if (recentFolders.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.history, size: 16),
              tooltip: 'Recent Folders',
              itemBuilder: (_) => recentFolders
                  .map(
                    (path) => PopupMenuItem<String>(
                      value: path,
                      child: Text(
                        path,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onSelected: (path) => widget.onFolderSelected?.call(path),
            ),
          const SizedBox(width: 4),
          // Recursive toggle
          Tooltip(
            message: isRecursive
                ? 'Recursive: scanning subfolders'
                : 'Non-recursive: top-level only',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () =>
                  ref.read(recursiveLoadingProvider.notifier).toggle(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRecursive
                          ? Icons.subdirectory_arrow_right
                          : Icons.horizontal_rule,
                      size: 14,
                      color: isRecursive
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Recursive',
                      style: TextStyle(
                        fontSize: 11,
                        color: isRecursive
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
