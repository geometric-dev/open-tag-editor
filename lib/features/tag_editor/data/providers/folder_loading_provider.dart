import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/error_handling/utils/error_entry_factory.dart';
import '../../../../features/settings/data/providers/settings_providers.dart';
import '../../presentation/widgets/address_bar.dart';
import '../../presentation/widgets/threshold_guard_dialog.dart';
import 'editor_state_provider.dart';
import 'file_list_provider.dart';
import 'recent_folders_provider.dart';
import 'recursive_loading_provider.dart';
import 'selection_provider.dart';
import 'service_providers.dart';

/// Orchestrates folder loading with recursive toggle and threshold guard.
///
/// This is not a provider itself but a utility class that coordinates
/// multiple providers during the folder loading process.
class FolderLoadingService {
  FolderLoadingService(this._ref);

  final WidgetRef _ref;

  /// Loads audio files from [folderPath] respecting recursive toggle
  /// and threshold guard settings.
  ///
  /// Requires a [BuildContext] for showing the threshold guard dialog.
  Future<void> loadFolder(BuildContext context, String folderPath) async {
    final statusNotifier = _ref.read(statusMessageProvider.notifier);
    final isRecursive = _ref.read(recursiveLoadingProvider);

    statusNotifier.state = 'Scanning folder...';

    // Check file count for threshold guard
    if (isRecursive) {
      final threshold =
          _ref.read(generalSettingsProvider).fileCountThreshold;
      final count = await FileUtils.countAudioFiles(
        folderPath,
        recursive: true,
        limit: threshold,
      );

      if (count > threshold && context.mounted) {
        final result = await ThresholdGuardDialog.show(
          context,
          fileCount: count,
        );

        switch (result) {
          case ThresholdGuardResult.loadAll:
            // Proceed with recursive loading
            break;
          case ThresholdGuardResult.topLevelOnly:
            // Load non-recursively
            await _loadFiles(folderPath, recursive: false);
            return;
          case ThresholdGuardResult.cancel:
          case null:
            statusNotifier.state = 'Load cancelled';
            return;
        }
      }
    }

    await _loadFiles(folderPath, recursive: isRecursive);
  }

  /// Loads files from dropped paths (files or folders).
  ///
  /// Computes the common parent directory for the address bar.
  Future<void> loadFromDrop(
    BuildContext context,
    List<String> paths,
  ) async {
    final statusNotifier = _ref.read(statusMessageProvider.notifier);
    statusNotifier.state = 'Loading files...';

    // Clear previous state before loading new files
    _ref.read(fileListProvider.notifier).clear();
    _ref.read(selectionProvider.notifier).clear();
    _ref.read(errorLogProvider.notifier).clear();

    final audioPaths = <String>[];

    for (final path in paths) {
      if (FileUtils.isAudioFile(path)) {
        audioPaths.add(path);
      } else {
        // Try as directory
        final isRecursive = _ref.read(recursiveLoadingProvider);
        final dirFiles = await FileUtils.listAudioFiles(
          path,
          recursive: isRecursive,
        );
        audioPaths.addAll(dirFiles.map((f) => f.path));

        // If it's a single folder drop, treat it like loadFolder
        if (paths.length == 1 && audioPaths.isNotEmpty) {
          _ref.read(loadedFolderPathProvider.notifier).state = path;
          _ref.read(recentFoldersProvider.notifier).addFolder(path);
        }
      }
    }

    if (audioPaths.isEmpty) {
      statusNotifier.state = 'No supported audio files found';
      return;
    }

    // Compute common parent for address bar if multiple files
    if (paths.length > 1 || FileUtils.isAudioFile(paths.first)) {
      final commonParent =
          FormatUtils.computeCommonParentDirectory(audioPaths);
      if (commonParent.isNotEmpty) {
        _ref.read(loadedFolderPathProvider.notifier).state = commonParent;
      }
    }

    // Read tags
    final reader = _ref.read(tagReaderProvider);
    statusNotifier.state = 'Reading tags for ${audioPaths.length} file(s)...';
    final files = await reader.readTagsBatch(audioPaths);

    // Detect files that failed to read tags
    final failedFiles = files.where((f) => f.readError != null).toList();
    if (failedFiles.isNotEmpty) {
      final failedPaths = failedFiles.map((f) => f.path).toList();
      final errorMessages = {
        for (final f in failedFiles) f.path: f.readError!,
      };
      final entries =
          ErrorEntryFactory.fromReadFailures(failedPaths, errorMessages);
      _ref.read(errorLogProvider.notifier).addEntries(entries);
    }

    _ref.read(fileListProvider.notifier).addFiles(files);
    statusNotifier.state = 'Loaded ${files.length} file(s)';
  }

  Future<void> _loadFiles(String folderPath, {required bool recursive}) async {
    final statusNotifier = _ref.read(statusMessageProvider.notifier);
    final reader = _ref.read(tagReaderProvider);

    // Clear previous state before loading new folder
    _ref.read(fileListProvider.notifier).clear();
    _ref.read(selectionProvider.notifier).clear();
    _ref.read(errorLogProvider.notifier).clear();

    final audioFiles = await FileUtils.listAudioFiles(
      folderPath,
      recursive: recursive,
    );

    if (audioFiles.isEmpty) {
      statusNotifier.state = 'No supported audio files found in folder';
      return;
    }

    statusNotifier.state = 'Reading tags for ${audioFiles.length} file(s)...';
    final paths = audioFiles.map((f) => f.path).toList();
    final files = await reader.readTagsBatch(paths);

    // Detect files that failed to read tags
    final failedFiles = files.where((f) => f.readError != null).toList();
    if (failedFiles.isNotEmpty) {
      final failedPaths = failedFiles.map((f) => f.path).toList();
      final errorMessages = {
        for (final f in failedFiles) f.path: f.readError!,
      };
      final entries =
          ErrorEntryFactory.fromReadFailures(failedPaths, errorMessages);
      _ref.read(errorLogProvider.notifier).addEntries(entries);
    }

    _ref.read(fileListProvider.notifier).addFiles(files);
    _ref.read(loadedFolderPathProvider.notifier).state = folderPath;
    _ref.read(recentFoldersProvider.notifier).addFolder(folderPath);
    _ref.read(windowStateProvider.notifier).setLastFolderPath(folderPath);
    statusNotifier.state = 'Loaded ${files.length} file(s)';
  }
}
