import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/update_provider.dart';
import 'update_dialog.dart';

/// Toolbar button that displays update status and opens the update dialog on click.
class UpdateButton extends ConsumerWidget {
  const UpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData icon;
    Color? iconColor;
    String tooltip;

    if (state.isReadyToInstall) {
      icon = Icons.restart_alt_rounded;
      iconColor = Colors.green.shade600;
      tooltip =
          'Update Ready: Restart to install ${state.updateInfo?.version ?? ""}';
    } else if (state.isDownloading) {
      icon = Icons.downloading_rounded;
      iconColor = colorScheme.primary;
      tooltip =
          'Downloading update: ${((state.downloadFraction ?? 0) * 100).toInt()}%';
    } else if (state.isUpdateAvailable) {
      icon = Icons.system_update_alt_rounded;
      iconColor = colorScheme.primary;
      tooltip = 'Update Available: ${state.updateInfo?.version ?? ""}';
    } else if (state.isFailed) {
      icon = Icons.update_disabled_rounded;
      iconColor = colorScheme.error;
      tooltip = 'Update check or download failed';
    } else {
      icon = Icons.update_rounded;
      iconColor = null;
      tooltip = 'Check for Updates';
    }

    return IconButton(
      key: const ValueKey('app_update_button'),
      icon: Stack(
        alignment: Alignment.topRight,
        children: [
          Icon(icon, size: 20, color: iconColor),
          if (state.isUpdateAvailable || state.isReadyToInstall)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: state.isReadyToInstall
                    ? Colors.green.shade600
                    : colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      tooltip: tooltip,
      onPressed: () => UpdateDialog.show(context),
      visualDensity: VisualDensity.compact,
    );
  }
}
