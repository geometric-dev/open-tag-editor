import 'package:flutter/material.dart';

import '../../data/models/batch_progress.dart';

/// Overlay widget that displays batch operation progress.
///
/// Shows a linear progress bar with "Processing X of Y files" text
/// during operations, and a completion summary when done.
class BatchProgressOverlay extends StatelessWidget {
  const BatchProgressOverlay({
    super.key,
    required this.progress,
    this.onDismiss,
  });

  /// The current batch progress state.
  final BatchProgress progress;

  /// Called when the user dismisses the completion summary.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!progress.isComplete) ...[
            LinearProgressIndicator(
              value: progress.total > 0
                  ? progress.completed / progress.total
                  : 0,
            ),
            const SizedBox(height: 8),
            Text(
              'Processing ${progress.completed} of ${progress.total} files...',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Icon(
              progress.hasFailures
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: progress.hasFailures
                  ? colorScheme.error
                  : colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              _buildSummaryText(),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (progress.hasFailures) ...[
              const SizedBox(height: 4),
              Text(
                progress.failures
                    .map((f) => '${_fileName(f.path)}: ${f.error}')
                    .join('\n'),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.error,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: onDismiss,
              child: const Text('Dismiss'),
            ),
          ],
        ],
      ),
    );
  }

  String _buildSummaryText() {
    final successes = progress.successes;
    final failures = progress.failures.length;

    if (failures == 0) {
      return '$successes file${successes == 1 ? '' : 's'} updated successfully.';
    }
    return '$successes succeeded, $failures failed.';
  }

  String _fileName(String path) {
    final separator = path.contains('\\') ? '\\' : '/';
    return path.split(separator).last;
  }
}
