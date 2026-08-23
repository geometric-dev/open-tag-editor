import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_tag_editor/features/folder_panel/data/bookmarks_notifier.dart';
import 'package:open_tag_editor/features/folder_panel/data/folder_entry.dart';
import 'package:open_tag_editor/features/folder_panel/data/quick_switcher_filter.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/recent_folders_provider.dart';
import 'package:path/path.dart' as p;

/// Keyboard-driven folder search overlay (Ctrl+G).
///
/// Displays a floating search overlay that filters the combined list of
/// bookmarks and recent folders by case-insensitive substring match.
/// Selecting an entry invokes [onFolderSelected] with the folder path.
class QuickSwitcherOverlay extends ConsumerStatefulWidget {
  /// Creates a [QuickSwitcherOverlay].
  const QuickSwitcherOverlay({
    super.key,
    required this.onFolderSelected,
    required this.onDismiss,
  });

  /// Called when the user selects a folder entry.
  final void Function(String path) onFolderSelected;

  /// Called when the overlay should be dismissed.
  final VoidCallback onDismiss;

  /// Shows the Quick Switcher as an overlay positioned at the top-center.
  static void show(
    BuildContext context,
    WidgetRef ref,
    void Function(String) onFolderSelected,
  ) {
    final overlay = Overlay.of(context);
    final container = ProviderScope.containerOf(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => UncontrolledProviderScope(
        container: container,
        child: _QuickSwitcherOverlayWrapper(
          onFolderSelected: (path) {
            entry.remove();
            onFolderSelected(path);
          },
          onDismiss: () => entry.remove(),
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  ConsumerState<QuickSwitcherOverlay> createState() =>
      _QuickSwitcherOverlayState();
}

/// Wrapper widget that provides tap-outside-to-dismiss behaviour.
class _QuickSwitcherOverlayWrapper extends ConsumerWidget {
  const _QuickSwitcherOverlayWrapper({
    required this.onFolderSelected,
    required this.onDismiss,
  });

  final void Function(String path) onFolderSelected;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // Dismiss on tap outside
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Overlay positioned at top-center
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: Center(
            child: QuickSwitcherOverlay(
              onFolderSelected: onFolderSelected,
              onDismiss: onDismiss,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickSwitcherOverlayState extends ConsumerState<QuickSwitcherOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _filter = QuickSwitcherFilter();
  int _highlightedIndex = 0;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _focusNode.onKeyEvent = _handleKeyEvent;
    // Autofocus after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<FolderEntry> _buildCombinedEntries() {
    final bookmarks = ref.read(bookmarksProvider);
    final recentFolders = ref.read(recentFoldersProvider);

    final entries = <FolderEntry>[];

    for (final bookmark in bookmarks) {
      entries.add(
        FolderEntry(
          path: bookmark.path,
          name: bookmark.name,
          source: FolderEntrySource.bookmark,
        ),
      );
    }

    for (final path in recentFolders) {
      entries.add(
        FolderEntry(
          path: path,
          name: p.basename(path).isEmpty ? path : p.basename(path),
          source: FolderEntrySource.recent,
        ),
      );
    }

    return entries;
  }

  void _onQueryChanged() {
    final newQuery = _controller.text;
    if (newQuery != _lastQuery) {
      _lastQuery = newQuery;
      _highlightedIndex = 0;
    }
    setState(() {});
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }

    final combined = _buildCombinedEntries();
    final entries = _filter.filter(combined, _controller.text);

    if (entries.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % entries.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedIndex =
            (_highlightedIndex - 1 + entries.length) % entries.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_highlightedIndex < entries.length) {
        widget.onFolderSelected(entries[_highlightedIndex].path);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers so the list updates if bookmarks/recent change
    ref.watch(bookmarksProvider);
    ref.watch(recentFoldersProvider);

    // Rebuild filtered entries when providers change
    final combined = _buildCombinedEntries();
    final entries = _filter.filter(combined, _controller.text);

    // Clamp highlighted index if entries shrink
    if (entries.isNotEmpty && _highlightedIndex >= entries.length) {
      _highlightedIndex = entries.length - 1;
    }

    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search folders...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  isDense: true,
                ),
              ),
            ),
            if (entries.isEmpty && _controller.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No matching folders'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _FolderEntryTile(
                      entry: entry,
                      isHighlighted: index == _highlightedIndex,
                      onTap: () => widget.onFolderSelected(entry.path),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single folder entry tile in the Quick Switcher results list.
class _FolderEntryTile extends StatelessWidget {
  const _FolderEntryTile({
    required this.entry,
    required this.isHighlighted,
    required this.onTap,
  });

  final FolderEntry entry;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      tileColor:
          isHighlighted ? theme.colorScheme.surfaceContainerHighest : null,
      leading: Icon(
        entry.source == FolderEntrySource.bookmark
            ? Icons.bookmark
            : Icons.access_time,
        size: 18,
        color: entry.source == FolderEntrySource.bookmark
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        entry.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entry.path,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
