import 'package:flutter/material.dart';

import 'data_grid.dart';

/// A non-interactive row displaying a folder path as a group header.
///
/// Spans the full grid width, uses a distinct background colour,
/// displays a folder icon + relative path in bold, and ignores
/// all pointer interactions.
class FolderSeparatorRow extends StatelessWidget {
  const FolderSeparatorRow({super.key, required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Container(
        height: DataGrid.rowHeight,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
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
    );
  }
}
