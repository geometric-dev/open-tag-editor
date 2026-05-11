import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/models/audio_file.dart';
import '../../../../../shared/services/taglib/taglib_types.dart';
import '../../../data/column_width_resolver.dart';
import '../../../data/models/column_definition.dart';
import '../../../data/models/selection_state.dart';
import '../../../data/providers/column_config_provider.dart';
import '../../../data/providers/editor_state_provider.dart';
import '../../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../../data/providers/selection_provider.dart';
import '../../../inline_cell_editing/models/cell_coordinate.dart';
import '../../../inline_cell_editing/providers/inline_cell_edit_provider.dart';
import '../../../inline_cell_editing/utils/column_editability.dart';
import '../../../inline_cell_editing/widgets/editable_cell.dart';
import '../address_bar.dart';
import 'column_headers.dart';
import 'marquee_overlay.dart';

/// The main data grid widget displaying audio files in a virtualized table.
///
/// Uses [ListView.builder] with fixed item extent for smooth scrolling
/// performance with hundreds of files.
class DataGrid extends ConsumerWidget {
  const DataGrid({super.key});

  static const double _rowHeight = 28;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(filteredSortedFileListProvider);
    final selection = ref.watch(selectionProvider);
    final config = ref.watch(columnConfigProvider);
    final rootFolder = ref.watch(loadedFolderPathProvider);

    final visibleColumns = config.visibleColumnIds
        .map((id) => defaultColumns.firstWhere(
              (c) => c.id == id,
              orElse: () => defaultColumns.first,
            ),)
        .toList();

    return Column(
      children: [
        Expanded(
          child: files.isEmpty
              ? _buildEmptyState(context)
              : Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) =>
                      _handleKeyEvent(ref, event),
                  child: _ScrollableDataGrid(
                    files: files,
                    selection: selection,
                    visibleColumns: visibleColumns,
                    widthOverrides: config.widthOverrides,
                    rootFolder: rootFolder,
                    onRowTap: (path, modifiers) => _handleRowTap(
                      ref,
                      path,
                      modifiers,
                      files.map((f) => f.path).toList(),
                    ),
                    onRowDoubleTap: (path) {
                      // Only open side panel if not in edit mode
                      final editState = ref.read(inlineCellEditProvider);
                      if (editState.isEditing) return;
                      ref.read(selectionProvider.notifier).select(path);
                      ref.read(tagPanelOpenProvider.notifier).state = true;
                    },
                    onAutoFit: (columnId, fitWidth) {
                      ref.read(columnConfigProvider.notifier).setColumnWidth(
                        columnId,
                        fitWidth,
                      );
                      ref.read(columnConfigProvider.notifier).persistWidths();
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audio_file_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Drop files or folders here\nor use the toolbar to open',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRowTap(
    WidgetRef ref,
    String path,
    _KeyModifiers modifiers,
    List<String> orderedPaths,
  ) {
    // Exit edit mode on any row tap (confirm current edit)
    final editState = ref.read(inlineCellEditProvider);
    if (editState.isEditing) {
      ref.read(inlineCellEditProvider.notifier).confirmEdit();
    }

    final notifier = ref.read(selectionProvider.notifier);

    if (modifiers.isCtrl && modifiers.isShift) {
      notifier.addRangeSelect(path, orderedPaths);
    } else if (modifiers.isShift) {
      notifier.rangeSelect(path, orderedPaths);
    } else if (modifiers.isCtrl) {
      notifier.toggleSelect(path);
    } else {
      notifier.select(path);
    }
  }

  KeyEventResult _handleKeyEvent(WidgetRef ref, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final editNotifier = ref.read(inlineCellEditProvider.notifier);
    final editState = ref.read(inlineCellEditProvider);
    final files = ref.read(filteredSortedFileListProvider);
    final orderedPaths = files.map((f) => f.path).toList();
    final selNotifier = ref.read(selectionProvider.notifier);

    final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.controlLeft ||
          k == LogicalKeyboardKey.controlRight,
    );
    final isShift = HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.shiftLeft ||
          k == LogicalKeyboardKey.shiftRight,
    );

    // If already editing, let the InlineTextField handle keys
    if (editState.isEditing) return KeyEventResult.ignored;

    // Ctrl+A: select all
    if (isCtrl &&
        !isShift &&
        event.logicalKey == LogicalKeyboardKey.keyA) {
      selNotifier.selectAll(orderedPaths);
      return KeyEventResult.handled;
    }

    // Ctrl+Shift+Home: extend selection to start
    if (isCtrl &&
        isShift &&
        event.logicalKey == LogicalKeyboardKey.home) {
      selNotifier.extendToStart(orderedPaths);
      return KeyEventResult.handled;
    }

    // Ctrl+Shift+End: extend selection to end
    if (isCtrl &&
        isShift &&
        event.logicalKey == LogicalKeyboardKey.end) {
      selNotifier.extendToEnd(orderedPaths);
      return KeyEventResult.handled;
    }

    // Arrow Down
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (isShift) {
        selNotifier.extendDown(orderedPaths);
      } else {
        selNotifier.moveDown(orderedPaths);
      }
      return KeyEventResult.handled;
    }

    // Arrow Up
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (isShift) {
        selNotifier.extendUp(orderedPaths);
      } else {
        selNotifier.moveUp(orderedPaths);
      }
      return KeyEventResult.handled;
    }

    // F2: enter edit mode on focused cell (guard is in enterEditMode)
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      final focused = editState.focusedCell;
      if (focused != null && isColumnEditable(focused.columnId)) {
        editNotifier.enterEditMode(
          focused,
          prePopulate: true,
          selectAll: true,
        );
        return KeyEventResult.handled;
      }
    }

    // Printable character: enter edit mode (guard is in enterEditMode)
    if (event.character != null &&
        event.character!.length == 1 &&
        !isCtrl) {
      final focused = editState.focusedCell;
      if (focused != null && isColumnEditable(focused.columnId)) {
        editNotifier.enterEditMode(
          focused,
          initialCharacter: event.character!,
        );
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}

class _ScrollableDataGrid extends StatefulWidget {
  const _ScrollableDataGrid({
    required this.files,
    required this.selection,
    required this.visibleColumns,
    required this.widthOverrides,
    required this.rootFolder,
    required this.onRowTap,
    required this.onRowDoubleTap,
    this.onAutoFit,
  });

  final List<AudioFile> files;
  final SelectionState selection;
  final List<ColumnDefinition> visibleColumns;
  final Map<String, double> widthOverrides;
  final String? rootFolder;
  final void Function(String path, _KeyModifiers modifiers) onRowTap;
  final void Function(String path) onRowDoubleTap;
  final void Function(String columnId, double fitWidth)? onAutoFit;

  @override
  State<_ScrollableDataGrid> createState() => _ScrollableDataGridState();
}

class _ScrollableDataGridState extends State<_ScrollableDataGrid> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  double get _totalWidth =>
      widget.visibleColumns.fold(
        0.0,
        (sum, c) =>
            sum +
            resolveEffectiveWidth(
              c.id,
              widget.widthOverrides,
              widget.visibleColumns,
            ),
      );

  void _handleAutoFit(String columnId) {
    final column = widget.visibleColumns.firstWhere(
      (c) => c.id == columnId,
      orElse: () => widget.visibleColumns.first,
    );

    // Measure header label width
    final headerPainter = TextPainter(
      text: TextSpan(
        text: column.label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final headerWidth = headerPainter.width;

    // Measure visible cell content widths
    final cellWidths = <double>[];
    for (final file in widget.files) {
      final value = column.valueExtractor?.call(
            file,
            rootFolder: widget.rootFolder,
          ) ??
          '';
      if (value.isNotEmpty) {
        final cellPainter = TextPainter(
          text: TextSpan(
            text: value,
            style: const TextStyle(fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        cellWidths.add(cellPainter.width);
      }
    }

    final fitWidth = calculateAutoFitWidth(
      cellWidths: cellWidths,
      headerLabelWidth: headerWidth,
    );

    widget.onAutoFit?.call(columnId, fitWidth);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalController,
      child: SizedBox(
        width: _totalWidth,
        child: Column(
          children: [
            ColumnHeaders(onAutoFit: _handleAutoFit),
            Expanded(
              child: MarqueeOverlay(
                rowHeight: DataGrid._rowHeight,
                scrollController: _verticalController,
                orderedPaths:
                    widget.files.map((f) => f.path).toList(),
                child: ListView.builder(
                  controller: _verticalController,
                  itemCount: widget.files.length,
                  itemExtent: DataGrid._rowHeight,
                  itemBuilder: (context, index) {
                    final file = widget.files[index];
                    final isSelected =
                        widget.selection.isSelected(file.path);

                    return _DataRow(
                      file: file,
                      rowIndex: index,
                      isSelected: isSelected,
                      visibleColumns: widget.visibleColumns,
                      widthOverrides: widget.widthOverrides,
                      rootFolder: widget.rootFolder,
                      onTap: (modifiers) =>
                          widget.onRowTap(file.path, modifiers),
                      onDoubleTap: () =>
                          widget.onRowDoubleTap(file.path),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends ConsumerWidget {
  const _DataRow({
    required this.file,
    required this.rowIndex,
    required this.isSelected,
    required this.visibleColumns,
    required this.widthOverrides,
    required this.rootFolder,
    required this.onTap,
    required this.onDoubleTap,
  });

  final AudioFile file;
  final int rowIndex;
  final bool isSelected;
  final List<ColumnDefinition> visibleColumns;
  final Map<String, double> widthOverrides;
  final String? rootFolder;
  final void Function(_KeyModifiers modifiers) onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final editState = ref.watch(inlineCellEditProvider);

    return InkWell(
      onTap: () {
        final isCtrl = HardwareKeyboard.instance.logicalKeysPressed
            .any((k) =>
                k == LogicalKeyboardKey.controlLeft ||
                k == LogicalKeyboardKey.controlRight ||
                k == LogicalKeyboardKey.metaLeft ||
                k == LogicalKeyboardKey.metaRight,);
        final isShift = HardwareKeyboard.instance.logicalKeysPressed
            .any((k) =>
                k == LogicalKeyboardKey.shiftLeft ||
                k == LogicalKeyboardKey.shiftRight,);
        onTap(_KeyModifiers(isCtrl: isCtrl, isShift: isShift));
      },
      onDoubleTap: editState.isEditing ? null : onDoubleTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: visibleColumns.map((column) {
            final effectiveWidth = resolveEffectiveWidth(
              column.id,
              widthOverrides,
              visibleColumns,
            );
            if (column.id == 'tagIndicator') {
              return _TagIndicatorCell(file: file, width: effectiveWidth);
            }
            final value = column.valueExtractor?.call(
                  file,
                  rootFolder: rootFolder,
                ) ??
                '';

            // Use EditableCell for editable columns
            if (isColumnEditable(column.id)) {
              return EditableCell(
                coordinate: CellCoordinate(
                  rowIndex: rowIndex,
                  columnId: column.id,
                ),
                value: value,
                width: effectiveWidth,
                isModified: file.isModified,
              );
            }

            return _TextCell(value: value, width: effectiveWidth);
          }).toList(),
        ),
      ),
    );
  }
}

class _TagIndicatorCell extends StatelessWidget {
  const _TagIndicatorCell({
    required this.file,
    required this.width,
  });

  final AudioFile file;
  final double width;

  @override
  Widget build(BuildContext context) {
    final hasTags = file.tags.values.any((v) => v.isNotEmpty);
    final formatName = _tagFormatName(file.tagFormat);

    return SizedBox(
      width: width,
      child: Center(
        child: Tooltip(
          message: hasTags ? formatName : 'No tags',
          child: Icon(
            hasTags ? Icons.label : Icons.label_outline,
            size: 14,
            color: hasTags
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  String _tagFormatName(TagFormat? format) {
    switch (format) {
      case TagFormat.id3v1:
        return 'ID3v1';
      case TagFormat.id3v2_3:
        return 'ID3v2.3';
      case TagFormat.id3v2_4:
        return 'ID3v2.4';
      case TagFormat.vorbisComment:
        return 'Vorbis Comment';
      case TagFormat.apeTag:
        return 'APE';
      case TagFormat.asf:
        return 'ASF';
      case TagFormat.mp4Atoms:
        return 'MP4';
      case TagFormat.unknown:
        return 'Tagged (format unknown)';
      case null:
        return 'None detected';
    }
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({
    required this.value,
    required this.width,
  });

  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          value,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _KeyModifiers {
  const _KeyModifiers({
    this.isCtrl = false,
    this.isShift = false,
  });

  final bool isCtrl;
  final bool isShift;
}
