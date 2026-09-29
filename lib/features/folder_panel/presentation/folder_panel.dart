import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../features/tag_editor/data/providers/recent_folders_provider.dart';
import '../data/bookmark_entry.dart';
import '../data/bookmarks_notifier.dart';
import '../data/folder_validator.dart';

/// A collapsible left panel showing bookmarks and recent folders.
///
/// Displays two scrollable sections — Bookmarks (top) and Recent Folders
/// (bottom) — allowing one-click folder loading. Invalid paths are marked
/// with a warning icon after asynchronous validation.
class FolderPanel extends ConsumerWidget {
  /// Creates a [FolderPanel].
  ///
  /// [onFolderSelected] is called when the user clicks a folder entry.
  const FolderPanel({super.key, required this.onFolderSelected});

  /// Called when the user clicks a folder entry to load it.
  final void Function(String path) onFolderSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    final recentFolders = ref.watch(recentFoldersProvider);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bookmarks section
          const _SectionHeader(title: 'Bookmarks'),
          Expanded(
            child: bookmarks.isEmpty
                ? const _EmptyPlaceholder(message: 'No bookmarks yet')
                : ReorderableListView.builder(
                    itemCount: bookmarks.length,
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) {
                      ref
                          .read(bookmarksProvider.notifier)
                          .moveTo(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final entry = bookmarks[index];
                      return _BookmarkTile(
                        key: ValueKey(entry.path),
                        entry: entry,
                        index: index,
                        onTap: () => onFolderSelected(entry.path),
                        onRemoveBookmark: () {
                          ref
                              .read(bookmarksProvider.notifier)
                              .removeBookmark(entry.path);
                        },
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          // Recent Folders section
          const _SectionHeader(title: 'Recent Folders'),
          Expanded(
            child: recentFolders.isEmpty
                ? const _EmptyPlaceholder(message: 'No recent folders')
                : ListView.builder(
                    itemCount: recentFolders.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final path = recentFolders[index];
                      return _RecentFolderTile(
                        path: path,
                        onTap: () => onFolderSelected(path),
                        onAddToBookmarks: () {
                          ref
                              .read(bookmarksProvider.notifier)
                              .addBookmark(path);
                        },
                        onRemoveFromHistory: () {
                          ref
                              .read(recentFoldersProvider.notifier)
                              .removeFolder(path);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A single bookmark entry tile with folder name and full path.
class _BookmarkTile extends StatefulWidget {
  const _BookmarkTile({
    super.key,
    required this.entry,
    required this.index,
    required this.onTap,
    required this.onRemoveBookmark,
  });

  final BookmarkEntry entry;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemoveBookmark;

  @override
  State<_BookmarkTile> createState() => _BookmarkTileState();
}

class _BookmarkTileState extends State<_BookmarkTile> {
  bool? _isValid;

  @override
  void initState() {
    super.initState();
    _validatePath();
  }

  @override
  void didUpdateWidget(_BookmarkTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.path != widget.entry.path) {
      _isValid = null;
      _validatePath();
    }
  }

  Future<void> _validatePath() async {
    final validator = FolderValidator();
    final result = await validator.validate(widget.entry.path);
    if (mounted) {
      setState(() => _isValid = result.isValid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isInvalid = _isValid == false;

    return GestureDetector(
      onSecondaryTapUp: (details) => _showContextMenu(context, details),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isInvalid
                            ? colorScheme.error
                            : colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      widget.entry.path,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isInvalid
                            ? colorScheme.error.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (isInvalid)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Folder not found',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.drag_handle,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    TapUpDetails details,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final result = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem<String>(
          value: 'remove_bookmark',
          child: Text('Remove Bookmark'),
        ),
      ],
    );
    if (result == 'remove_bookmark') {
      widget.onRemoveBookmark();
    }
  }
}

/// A single recent folder entry tile with bold name and truncated path.
class _RecentFolderTile extends StatefulWidget {
  const _RecentFolderTile({
    required this.path,
    required this.onTap,
    required this.onAddToBookmarks,
    required this.onRemoveFromHistory,
  });

  final String path;
  final VoidCallback onTap;
  final VoidCallback onAddToBookmarks;
  final VoidCallback onRemoveFromHistory;

  @override
  State<_RecentFolderTile> createState() => _RecentFolderTileState();
}

class _RecentFolderTileState extends State<_RecentFolderTile> {
  bool? _isValid;

  @override
  void initState() {
    super.initState();
    _validatePath();
  }

  @override
  void didUpdateWidget(_RecentFolderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _isValid = null;
      _validatePath();
    }
  }

  Future<void> _validatePath() async {
    final validator = FolderValidator();
    final result = await validator.validate(widget.path);
    if (mounted) {
      setState(() => _isValid = result.isValid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isInvalid = _isValid == false;
    final folderName = p.basename(widget.path);

    return GestureDetector(
      onSecondaryTapUp: (details) => _showContextMenu(context, details),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName.isEmpty ? widget.path : folderName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isInvalid
                            ? colorScheme.error
                            : colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      widget.path,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isInvalid
                            ? colorScheme.error.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (isInvalid)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Folder not found',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    TapUpDetails details,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final result = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem<String>(
          value: 'add_to_bookmarks',
          child: Text('Add to Bookmarks'),
        ),
        PopupMenuItem<String>(
          value: 'remove_from_history',
          child: Text('Remove from History'),
        ),
      ],
    );
    if (result == 'add_to_bookmarks') {
      widget.onAddToBookmarks();
    } else if (result == 'remove_from_history') {
      widget.onRemoveFromHistory();
    }
  }
}
