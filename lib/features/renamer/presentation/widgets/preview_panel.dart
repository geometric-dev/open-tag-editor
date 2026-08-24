import 'package:flutter/material.dart';

import '../../data/models/rename_preview.dart';

/// Displays a two-column preview of rename operations.
///
/// Shows original filename → new filename with visual indicators for
/// conflicts, errors, and unchanged files.
class PreviewPanel extends StatelessWidget {
  const PreviewPanel({
    super.key,
    required this.previews,
  });

  /// The list of rename previews to display.
  final List<RenamePreview> previews;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderRow(previews: previews),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: previews.isEmpty
                ? const Center(
                    child: Text(
                      'No files loaded',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: previews.length,
                    itemExtent: 52,
                    itemBuilder: (context, index) {
                      return _PreviewRow(preview: previews[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.previews});

  final List<RenamePreview> previews;

  @override
  Widget build(BuildContext context) {
    final renameCount =
        previews.where((p) => p.status == RenamePreviewStatus.ok).length;
    final conflictCount =
        previews.where((p) => p.status == RenamePreviewStatus.conflict).length;
    final errorCount =
        previews.where((p) => p.status == RenamePreviewStatus.error).length;

    return Text(
      '$renameCount will be renamed, $conflictCount conflicts, $errorCount errors',
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.preview});

  final RenamePreview preview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = preview.status;

    final Color newNameColor;
    final Color? backgroundTint;

    switch (status) {
      case RenamePreviewStatus.ok:
        newNameColor = colorScheme.primary;
        backgroundTint = null;
      case RenamePreviewStatus.conflict:
        newNameColor = Colors.orange;
        backgroundTint = Colors.orange.withValues(alpha: 0.05);
      case RenamePreviewStatus.error:
        newNameColor = colorScheme.error;
        backgroundTint = colorScheme.error.withValues(alpha: 0.05);
      case RenamePreviewStatus.unchanged:
        newNameColor = colorScheme.onSurfaceVariant;
        backgroundTint = null;
    }

    final bool willChange = status != RenamePreviewStatus.unchanged;

    return Container(
      color: backgroundTint,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  preview.originalFilename,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    decoration: willChange ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  preview.newFilename,
                  style: TextStyle(
                    fontSize: 11,
                    color: newNameColor,
                    fontWeight:
                        willChange ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _StatusIcon(status: status),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final RenamePreviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (status) {
      RenamePreviewStatus.ok => (Icons.check_circle, Colors.green),
      RenamePreviewStatus.conflict => (Icons.warning, Colors.orange),
      RenamePreviewStatus.error => (
          Icons.error,
          Theme.of(context).colorScheme.error,
        ),
      RenamePreviewStatus.unchanged => (Icons.remove, Colors.grey),
    };

    return Icon(icon, size: 16, color: color);
  }
}
