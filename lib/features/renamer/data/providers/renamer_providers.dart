import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../tag_editor/data/providers/file_list_provider.dart';
import '../../../tag_editor/data/providers/selection_provider.dart';
import '../models/mask_preset.dart';
import '../models/renamer_state.dart';
import '../preset_notifier.dart';
import '../renamer_state_notifier.dart';

/// Provider for the preset notifier.
final presetProvider =
    StateNotifierProvider<PresetNotifier, List<MaskPreset>>((ref) {
  return PresetNotifier();
});

/// Provider for the renamer state notifier.
///
/// This provider depends on the current file list and selection state.
/// Uses selected files if any are selected, otherwise uses all files.
final renamerStateProvider = StateNotifierProvider.autoDispose<
    RenamerStateNotifier, RenamerState>((ref) {
  final allFiles = ref.watch(fileListProvider);
  final selection = ref.watch(selectionProvider);
  final undoRedo = ref.read(undoRedoProvider.notifier);

  // Use selected files if any are selected, otherwise use all files.
  final files = selection.selectedPaths.isEmpty
      ? allFiles
      : allFiles
          .where((f) => selection.selectedPaths.contains(f.path))
          .toList();

  return RenamerStateNotifier(
    files: files,
    undoRedoManager: undoRedo,
  );
});
