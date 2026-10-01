import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/format_utils.dart';
import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../shared/models/audio_file.dart';
import '../../data/providers/editor_state_provider.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/selection_provider.dart';

/// Enhanced status bar showing file counts, durations, and sizes.
class EnhancedStatusBar extends ConsumerWidget {
  const EnhancedStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(fileListProvider);
    final selection = ref.watch(selectionProvider);
    final modifiedCount = ref.watch(modifiedFileCountProvider);
    final status = ref.watch(statusMessageProvider);
    final errorCount = ref.watch(errorCountProvider);
    final errorPanelVisible = ref.watch(errorPanelVisibleProvider);

    final selectedFiles = files
        .where((f) => selection.selectedPaths.contains(f.path))
        .toList();

    final totalDuration = _sumDuration(files);
    final selectedDuration = _sumDuration(selectedFiles);
    final totalSize = files.fold<int>(0, (sum, f) => sum + f.fileSize);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
      child: Row(
        children: [
          // Status message. A live region so a screen reader announces the
          // result of a save or a load; without it the only feedback from a
          // batch operation is silence.
          //
          // Expanded, not Expanded+Spacer: the status text takes the slack
          // and the trailing stats keep their natural width.
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: status,
              excludeSemantics: true,
              child: Text(
                status,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Error count indicator
          if (errorCount > 0) ...[
            Semantics(
              button: true,
              label:
                  '$errorCount ${errorCount == 1 ? 'error' : 'errors'}. '
                  '${errorPanelVisible ? 'Hide' : 'Show'} details',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () =>
                    ref.read(errorPanelVisibleProvider.notifier).state =
                        !errorPanelVisible,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$errorCount ${errorCount == 1 ? 'error' : 'errors'}',
                      style: TextStyle(fontSize: 11, color: colorScheme.error),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Modified count
          if (modifiedCount > 0) ...[
            Icon(Icons.edit, size: 12, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              '$modifiedCount modified',
              style: TextStyle(fontSize: 11, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
          ],
          // Selected count
          if (selection.hasSelection) ...[
            Text(
              '${selection.count} selected',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 8),
            Text(
              FormatUtils.formatTotalDuration(selectedDuration),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 12),
          ],
          // Total stats
          Text('${files.length} files', style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 8),
          Text(
            FormatUtils.formatTotalDuration(totalDuration),
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            FormatUtils.formatFileSize(totalSize),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  double _sumDuration(List<AudioFile> files) {
    return files.fold<double>(0, (sum, f) => sum + (f.duration ?? 0));
  }
}
