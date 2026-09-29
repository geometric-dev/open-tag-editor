import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../features/settings/data/providers/settings_providers.dart';
import '../../../../shared/models/audio_file.dart';
import 'file_list_provider.dart';
import 'selection_provider.dart';

/// Tracks the currently selected file paths.
///
/// Bridges to the new [selectionProvider] for backward compatibility.
final selectedFilePathsProvider = Provider<Set<String>>((ref) {
  return ref.watch(selectionProvider).selectedPaths;
});

/// Returns the AudioFile objects for the current selection.
final selectedFilesProvider = Provider<List<AudioFile>>((ref) {
  final allFiles = ref.watch(fileListProvider);
  final selection = ref.watch(selectionProvider);

  if (!selection.hasSelection) return [];

  return allFiles
      .where((f) => selection.selectedPaths.contains(f.path))
      .toList();
});

/// Returns the single selected file (if exactly one is selected).
final singleSelectedFileProvider = Provider<AudioFile?>((ref) {
  final selected = ref.watch(selectedFilesProvider);
  return selected.length == 1 ? selected.first : null;
});

/// Tracks whether there are unsaved modifications.
final hasUnsavedChangesProvider = Provider<bool>((ref) {
  final files = ref.watch(fileListProvider);
  return files.any((f) => f.isModified);
});

/// Returns the count of modified files.
final modifiedFileCountProvider = Provider<int>((ref) {
  final files = ref.watch(fileListProvider);
  return files.where((f) => f.isModified).length;
});

/// Status message shown in the status bar.
final statusMessageProvider = StateProvider<String>((ref) => 'Ready');

/// Whether the tag editor side panel is open.
///
/// Initialises from the persisted window state and syncs changes back
/// to the [WindowStateNotifier] for persistence.
final tagPanelOpenProvider = StateProvider<bool>((ref) {
  return ref.read(windowStateProvider).isTagPanelOpen;
});

/// The available tabs within the tag edit side panel.
enum TagPanelTab { tags, albumArt, fileInfo }

/// Tracks which tab is currently active in the tag edit panel.
final tagPanelActiveTabProvider = StateProvider<TagPanelTab>(
  (ref) => TagPanelTab.tags,
);
