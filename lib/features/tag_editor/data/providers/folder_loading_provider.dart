import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/error_handling/utils/error_entry_factory.dart';
import '../../../../features/settings/data/providers/settings_providers.dart';
import '../../../../shared/models/audio_file.dart';
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
/// Reads a provider value without depending on the widget layer.
///
/// Both `Ref.read` and `WidgetRef.read` satisfy this signature, so call
/// sites pass `ref.read` as a tear-off.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// This is not a provider itself but a utility class that coordinates
/// multiple providers during the folder loading process.
class FolderLoadingService {
  FolderLoadingService(this._read);

  final ProviderReader _read;

  /// Loads audio files from [folderPath] respecting recursive toggle
  /// and threshold guard settings.
  ///
  /// Requires a [BuildContext] for showing the threshold guard dialog.
  Future<void> loadFolder(BuildContext context, String folderPath) async {
    final statusNotifier = _read(statusMessageProvider.notifier);
    final isRecursive = _read(recursiveLoadingProvider);

    statusNotifier.state = 'Scanning folder...';

    // Check file count for threshold guard
    if (isRecursive) {
      final threshold = _read(generalSettingsProvider).fileCountThreshold;
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
  Future<void> loadFromDrop(BuildContext context, List<String> paths) async {
    final statusNotifier = _read(statusMessageProvider.notifier);
    statusNotifier.state = 'Loading files...';

    // Clear previous state before loading new files
    _read(fileListProvider.notifier).clear();
    _read(selectionProvider.notifier).clear();
    _read(errorLogProvider.notifier).clear();

    final audioPaths = <String>[];

    for (final path in paths) {
      if (FileUtils.isAudioFile(path)) {
        audioPaths.add(path);
      } else {
        // Try as directory
        final isRecursive = _read(recursiveLoadingProvider);
        final dirFiles = await FileUtils.listAudioFiles(
          path,
          recursive: isRecursive,
        );
        audioPaths.addAll(dirFiles.map((f) => f.path));

        // If it's a single folder drop, treat it like loadFolder
        if (paths.length == 1 && audioPaths.isNotEmpty) {
          _read(loadedFolderPathProvider.notifier).state = path;
          _read(recentFoldersProvider.notifier).addFolder(path);
        }
      }
    }

    if (audioPaths.isEmpty) {
      statusNotifier.state = 'No supported audio files found';
      return;
    }

    // Compute common parent for address bar if multiple files
    if (paths.length > 1 || FileUtils.isAudioFile(paths.first)) {
      final commonParent = FormatUtils.computeCommonParentDirectory(audioPaths);
      if (commonParent.isNotEmpty) {
        _read(loadedFolderPathProvider.notifier).state = commonParent;
      }
    }

    // Read tags
    final reader = _read(tagReaderProvider);
    statusNotifier.state = 'Reading tags for ${audioPaths.length} file(s)...';
    final files = await reader.readTagsBatch(audioPaths);

    // Detect files that failed to read tags
    final failedFiles = files.where((f) => f.readError != null).toList();
    if (failedFiles.isNotEmpty) {
      final failedPaths = failedFiles.map((f) => f.path).toList();
      final errorMessages = {for (final f in failedFiles) f.path: f.readError!};
      final entries = ErrorEntryFactory.fromReadFailures(
        failedPaths,
        errorMessages,
      );
      _read(errorLogProvider.notifier).addEntries(entries);
    }

    _read(fileListProvider.notifier).addFiles(files);
    statusNotifier.state = 'Loaded ${files.length} file(s)';
  }

  /// Re-reads tags for the files currently in the list, in place (F5).
  ///
  /// Unlike a folder reload this preserves the selection, the undo history
  /// and the loaded-folder state, because nothing about *which* files are
  /// open has changed — only their contents. Files with unsaved edits are
  /// skipped rather than overwritten: re-reading them would silently discard
  /// work the user has not saved, and a "refresh" that destroys unsaved
  /// changes is worse than no refresh.
  ///
  /// Returns the number of files re-read, or `null` when there was nothing
  /// to do.
  Future<int?> reloadTagsFromDisk() async {
    final statusNotifier = _read(statusMessageProvider.notifier);
    final fileNotifier = _read(fileListProvider.notifier);
    final current = fileNotifier.currentFiles;
    if (current.isEmpty) return null;

    final dirty = current.where((f) => f.isModified).toSet();
    final candidates = current
        .where((f) => !dirty.contains(f))
        .map((f) => f.path)
        .toList();

    if (candidates.isEmpty) {
      statusNotifier.state = dirty.isEmpty
          ? 'No files to refresh'
          : 'All ${dirty.length} file(s) have unsaved changes - not refreshed';
      return null;
    }

    statusNotifier.state = 'Refreshing ${candidates.length} file(s)...';
    final reread = await _read(tagReaderProvider).readTagsBatch(candidates);

    // Merge by path: the re-read results replace the entry wholesale, so
    // audio properties and the fresh originalTags both come along.
    final byPath = {for (final file in reread) file.path: file};
    final updated = <AudioFile>[];
    for (final file in current) {
      final fresh = byPath[file.path];
      if (fresh != null) updated.add(fresh);
    }
    fileNotifier.updateFiles(updated);

    statusNotifier.state = dirty.isEmpty
        ? 'Refreshed ${updated.length} file(s)'
        : 'Refreshed ${updated.length} file(s); ${dirty.length} with unsaved '
              'changes were skipped';
    return updated.length;
  }

  Future<void> _loadFiles(String folderPath, {required bool recursive}) async {
    final statusNotifier = _read(statusMessageProvider.notifier);
    final reader = _read(tagReaderProvider);

    // Clear previous state before loading new folder
    _read(fileListProvider.notifier).clear();
    _read(selectionProvider.notifier).clear();
    _read(errorLogProvider.notifier).clear();

    final audioFiles = await FileUtils.listAudioFiles(
      folderPath,
      recursive: recursive,
    );

    if (audioFiles.isEmpty) {
      statusNotifier.state = 'No supported audio files found in folder';
      return;
    }

    statusNotifier.state = 'Reading tags for ${audioFiles.length} file(s)...';
    // Publish the count so the UI can show a determinate progress bar.
    // Without it a large load looked identical to an idle grid, and the only
    // feedback was a status-bar line most users never look at.
    final progress = _read(folderLoadProgressProvider.notifier);
    progress.state = FolderLoadProgress(total: audioFiles.length, completed: 0);

    final paths = audioFiles.map((f) => f.path).toList();
    final files = await reader.readTagsBatch(paths);
    progress.state = FolderLoadProgress(
      total: audioFiles.length,
      completed: files.length,
    );

    // Detect files that failed to read tags
    final failedFiles = files.where((f) => f.readError != null).toList();
    if (failedFiles.isNotEmpty) {
      final failedPaths = failedFiles.map((f) => f.path).toList();
      final errorMessages = {for (final f in failedFiles) f.path: f.readError!};
      final entries = ErrorEntryFactory.fromReadFailures(
        failedPaths,
        errorMessages,
      );
      _read(errorLogProvider.notifier).addEntries(entries);
    }

    _read(fileListProvider.notifier).addFiles(files);
    _read(loadedFolderPathProvider.notifier).state = folderPath;
    _read(recentFoldersProvider.notifier).addFolder(folderPath);
    _read(windowStateProvider.notifier).setLastFolderPath(folderPath);
    statusNotifier.state = 'Loaded ${files.length} file(s)';
    progress.state = FolderLoadProgress(
      total: audioFiles.length,
      completed: audioFiles.length,
    );
  }
}

/// Progress of the current folder load, for the UI to render.
class FolderLoadProgress {
  const FolderLoadProgress({required this.total, required this.completed});

  /// No load in flight.
  static const FolderLoadProgress idle = FolderLoadProgress(
    total: 0,
    completed: 0,
  );

  final int total;
  final int completed;

  bool get isActive => total > 0 && completed < total;

  /// 0..1, or null when indeterminate.
  double? get fraction => total <= 0 ? null : completed / total;
}

/// Folder-load progress, cleared when a load finishes or is abandoned.
final folderLoadProgressProvider = StateProvider<FolderLoadProgress>(
  (ref) => FolderLoadProgress.idle,
);
