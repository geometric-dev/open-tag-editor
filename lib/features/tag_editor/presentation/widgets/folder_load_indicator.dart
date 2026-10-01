import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/folder_loading_provider.dart';

/// Determinate progress bar for the current folder load.
///
/// Every dialog in the app has a spinner; loading a folder had none. On a
/// large library the grid simply stayed as it was, which looks identical to
/// an idle window -- the only signal was a status-bar line, and for a
/// multi-thousand-file read that stays put for long enough that users
/// reasonably conclude the click did nothing.
class FolderLoadIndicator extends ConsumerWidget {
  const FolderLoadIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(folderLoadProgressProvider);
    if (!progress.isActive) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: 'Reading tags: ${progress.completed} of ${progress.total} files',
      excludeSemantics: true,
      child: Container(
        height: 3,
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          // Clamped because a completed count above the total would
          // otherwise overflow the bar.
          widthFactor: (progress.fraction ?? 0).clamp(0.0, 1.0),
          child: ColoredBox(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}
