import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_grid.dart';

/// An interactive row displaying a folder path as a group header.
///
/// Spans the full grid width, uses a distinct background colour,
/// displays a folder icon + relative path in bold, and acts as a
/// selector for all subfiles in the group when clicked.
class FolderSeparatorRow extends StatelessWidget {
  const FolderSeparatorRow({
    super.key,
    required this.relativePath,
    this.isSelected = false,
    this.onTap,
  });

  final String relativePath;
  final bool isSelected;
  final void Function(KeyModifiers modifiers)? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        canRequestFocus: false,
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap == null
            ? null
            : () {
                final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any(
                  (k) =>
                      k == LogicalKeyboardKey.controlLeft ||
                      k == LogicalKeyboardKey.controlRight ||
                      k == LogicalKeyboardKey.metaLeft ||
                      k == LogicalKeyboardKey.metaRight,
                );
                final isShift = HardwareKeyboard.instance.logicalKeysPressed
                    .any(
                      (k) =>
                          k == LogicalKeyboardKey.shiftLeft ||
                          k == LogicalKeyboardKey.shiftRight,
                    );
                onTap!(KeyModifiers(isCtrl: isCtrl, isShift: isShift));
              },
        child: Container(
          height: DataGrid.rowHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(Icons.folder, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  relativePath,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
