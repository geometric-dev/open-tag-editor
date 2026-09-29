import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../../settings/presentation/pages/settings_page.dart';
import '../../../data/providers/folder_loading_provider.dart';
import '../../../data/providers/recent_folders_provider.dart';
import '../../../data/services/editor_open_service.dart';

/// What the editor shows when no files are loaded.
///
/// Intentionally a real starting point rather than a dead end: it offers the
/// same actions as the toolbar, plus recent folders, so a returning user does
/// not have to hunt for the toolbar to get back to where they were.
class EmptyStateView extends ConsumerWidget {
  const EmptyStateView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recent = ref.watch(recentFoldersProvider).take(6).toList();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.library_music_outlined,
                size: 56,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                'Open Tag Editor',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Drop audio files or folders anywhere in this window',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Supported: ${EditorOpenService.formatSummary()}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        EditorOpenService(ref.read).openFolder(context, ref),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Open Folder'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        EditorOpenService(ref.read).openFiles(context, ref),
                    icon: const Icon(Icons.audio_file, size: 18),
                    label: const Text('Open Files'),
                  ),
                ],
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Recent folders',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                for (final path in recent)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, size: 18),
                    title: Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () async {
                      if (!context.mounted) return;
                      final proceed = await UnsavedChangesGuard.check(
                        context: context,
                        ref: ref,
                        clearUndoOnDiscard: true,
                      );
                      if (!proceed || !context.mounted) return;
                      await FolderLoadingService(
                        ref.read,
                      ).loadFolder(context, path);
                    },
                  ),
              ],
              const SizedBox(height: 20),
              _FeatureHighlights(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => SettingsDialog.show(context),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureHighlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const highlights = <(IconData, String)>[
      (Icons.tag, 'Edit tags inline, in a panel, or across a whole selection'),
      (Icons.drive_file_rename_outline, 'Rename files from a mask'),
      (Icons.travel_explore, 'Look up metadata from Discogs or MusicBrainz'),
      (Icons.swap_horiz, 'Sync ID3v1/ID3v2 and strip or clear tags'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, label) in highlights)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
