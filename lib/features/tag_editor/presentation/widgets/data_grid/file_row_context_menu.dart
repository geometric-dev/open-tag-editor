import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/editor_state_provider.dart';
import '../../../data/providers/selection_provider.dart';

/// What the user picked from a file row's context menu.
enum FileRowAction { editTags, refreshFromDisk, save, removeFromList }

/// Right-click menu for a file row in the grid.
///
/// The grid is custom-painted and had no context menu at all, which left two
/// of the most-used operations reachable only by keyboard shortcut: Delete to
/// remove files, and saving. It also left PRD 18's "right-click context menu"
/// requirement unmet.
///
/// The menu acts on the current *selection*, not the clicked row, because that
/// is what the mouse has already established by the time a menu opens. A row
/// that is not part of the selection is selected first, so acting on a row the
/// user has not selected never happens behind a menu they opened on it.
class FileRowContextMenu {
  const FileRowContextMenu._();

  /// Shows the menu at [position] and returns the chosen action.
  static Future<FileRowAction?> show(
    BuildContext context,
    WidgetRef ref, {
    required String rowPath,
    required Offset position,
  }) {
    final selection = ref.read(selectionProvider);
    final selectionNotifier = ref.read(selectionProvider.notifier);
    if (!selection.isSelected(rowPath)) {
      selectionNotifier.select(rowPath);
    }

    final selected = ref.read(selectedFilesProvider);
    final count = selected.length;
    final hasModified = selected.any((f) => f.isModified);

    return showMenu<FileRowAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: FileRowAction.editTags,
          child: Text('Edit tags', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: FileRowAction.refreshFromDisk,
          child: Text('Refresh from disk', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: FileRowAction.save,
          enabled: hasModified,
          child: Text(
            count == 1 ? 'Save this file' : 'Save $count modified file(s)',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: FileRowAction.removeFromList,
          child: Text(
            count == 1 ? 'Remove from list' : 'Remove $count file(s) from list',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
