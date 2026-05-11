import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/column_width_resolver.dart';
import '../../../data/models/column_definition.dart';
import '../../../data/models/sort_state.dart';
import '../../../data/providers/column_config_provider.dart';
import '../../../data/providers/sort_state_provider.dart';
import 'resize_handle.dart';

/// Column header row for the data grid.
///
/// Supports click-to-sort, right-click context menu for show/hide,
/// drag-to-resize columns, and double-click to auto-fit.
class ColumnHeaders extends ConsumerWidget {
  const ColumnHeaders({
    super.key,
    this.onAutoFit,
  });

  /// Callback to auto-fit a column to its content width.
  /// Called with the column ID when the resize handle is double-clicked.
  final void Function(String columnId)? onAutoFit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(columnConfigProvider);
    final sortState = ref.watch(sortStateProvider);

    // Get visible column definitions in order
    final visibleColumns = config.visibleColumnIds
        .map((id) => defaultColumns.firstWhere(
              (c) => c.id == id,
              orElse: () => defaultColumns.first,
            ),)
        .toList();

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: visibleColumns.map((column) {
          final effectiveWidth = resolveEffectiveWidth(
            column.id,
            config.widthOverrides,
            visibleColumns,
          );
          return _ColumnHeaderCell(
            column: column,
            effectiveWidth: effectiveWidth,
            sortState: sortState,
            onSort: () =>
                ref.read(sortStateProvider.notifier).toggleSort(column.id),
            onToggleVisibility: (columnId) =>
                ref.read(columnConfigProvider.notifier).toggleVisibility(columnId),
            onResize: (newWidth) =>
                ref.read(columnConfigProvider.notifier).setColumnWidth(column.id, newWidth),
            onResizeEnd: () =>
                ref.read(columnConfigProvider.notifier).persistWidths(),
            onAutoFit: () => onAutoFit?.call(column.id),
            onResetWidths: () =>
                ref.read(columnConfigProvider.notifier).resetColumnWidths(),
            allColumns: defaultColumns,
            visibleColumnIds: config.visibleColumnIds,
          );
        }).toList(),
      ),
    );
  }
}

class _ColumnHeaderCell extends StatelessWidget {
  const _ColumnHeaderCell({
    required this.column,
    required this.effectiveWidth,
    required this.sortState,
    required this.onSort,
    required this.onToggleVisibility,
    required this.onResize,
    required this.onResizeEnd,
    required this.onAutoFit,
    required this.onResetWidths,
    required this.allColumns,
    required this.visibleColumnIds,
  });

  final ColumnDefinition column;
  final double effectiveWidth;
  final SortState sortState;
  final VoidCallback onSort;
  final void Function(String columnId) onToggleVisibility;
  final void Function(double newWidth) onResize;
  final VoidCallback onResizeEnd;
  final VoidCallback onAutoFit;
  final VoidCallback onResetWidths;
  final List<ColumnDefinition> allColumns;
  final List<String> visibleColumnIds;

  @override
  Widget build(BuildContext context) {
    final isSorted = sortState.columnId == column.id;
    final isResizable = column.id != 'tagIndicator';

    return SizedBox(
      width: effectiveWidth,
      child: Stack(
        children: [
          GestureDetector(
            onTap: column.id != 'tagIndicator' ? onSort : null,
            onSecondaryTapUp: (details) {
              _showContextMenu(context, details.globalPosition);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      column.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSorted)
                    Icon(
                      sortState.direction == SortDirection.ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 12,
                    ),
                ],
              ),
            ),
          ),
          if (isResizable)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: ResizeHandle(
                columnId: column.id,
                currentWidth: effectiveWidth,
                onDragUpdate: onResize,
                onDragEnd: onResizeEnd,
                onDoubleTap: onAutoFit,
              ),
            ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final items = <PopupMenuEntry<String>>[];

    // Column visibility toggles
    for (final col in allColumns) {
      if (col.isFixed) continue; // Can't toggle fixed columns
      items.add(
        CheckedPopupMenuItem<String>(
          value: col.id,
          checked: visibleColumnIds.contains(col.id),
          child: Text(col.label, style: const TextStyle(fontSize: 12)),
        ),
      );
    }

    // Separator and reset option
    items.add(const PopupMenuDivider());
    items.add(
      const PopupMenuItem<String>(
        value: '__reset_widths__',
        child: Text('Reset Column Widths', style: TextStyle(fontSize: 12)),
      ),
    );

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: items,
    ).then((value) {
      if (value == '__reset_widths__') {
        onResetWidths();
      } else if (value != null) {
        onToggleVisibility(value);
      }
    });
  }
}
