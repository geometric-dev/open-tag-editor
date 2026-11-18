import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/format_utils.dart';
import '../../data/providers/update_provider.dart';

/// Desktop dialog displaying current and available versions, release notes,
/// background download progress, and the "Update now" / restart actions.
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  /// Displays the update dialog as a modal overlay.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const UpdateDialog(),
    );
  }

  Future<void> _openReleaseUrl(BuildContext context, String? url) async {
    final target =
        url ??
        'https://github.com/geometric-dev/open-tag-editor/releases/latest';
    final uri = Uri.parse(target);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Fallback
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final currentVer = state.currentVersion.toString();
    final latestVer = state.updateInfo?.version.toString() ?? currentVer;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('Software Update', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Versions Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Version',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentVer,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Latest Available',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  latestVer,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: state.isUpdateAvailable
                                        ? colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Banners
                    if (state.isChecking) ...[
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Checking GitHub for new releases...',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ] else if (state.isUpToDate) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Open Tag Editor is up to date.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (state.isDownloading) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Downloading update: '
                                  '${((state.downloadFraction ?? 0) * 100).toInt()}%'
                                  ' (${FormatUtils.formatFileSize(state.downloadedBytes)} / '
                                  '${FormatUtils.formatFileSize(state.totalBytes)})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: state.downloadFraction,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ] else if (state.isReadyToInstall) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.green.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Update downloaded and staged. Click below to restart and install.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (state.isFailed) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: colorScheme.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.errorMessage ??
                                        'An error occurred during update.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'If downloading within the app continues to fail, you can download the release directly from GitHub:',
                              style: TextStyle(fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () =>
                                  _openReleaseUrl(context, state.releaseUrl),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.open_in_new,
                                    size: 13,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Visit GitHub Release Page',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Release notes
                    if (state.updateInfo?.releaseNotes.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Release Notes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            state.updateInfo!.releaseNotes,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  if (state.isFailed) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('GitHub Release'),
                      onPressed: () =>
                          _openReleaseUrl(context, state.releaseUrl),
                    ),
                    FilledButton(
                      onPressed: () => ref
                          .read(updateStateProvider.notifier)
                          .checkForUpdate(),
                      child: const Text('Try Again'),
                    ),
                  ] else if (state.isReadyToInstall) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('Restart & Install Now'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref
                            .read(updateStateProvider.notifier)
                            .applyUpdateAndRestart();
                      },
                    ),
                  ] else if (state.isDownloading) ...[
                    const FilledButton(
                      onPressed: null,
                      child: Text('Downloading...'),
                    ),
                  ] else if (state.isUpdateAvailable) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Update Now'),
                      onPressed: () {
                        ref.read(updateStateProvider.notifier).startDownload();
                      },
                    ),
                  ] else if (state.isUpToDate) ...[
                    OutlinedButton(
                      onPressed: () => ref
                          .read(updateStateProvider.notifier)
                          .checkForUpdate(),
                      child: const Text('Check Again'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
