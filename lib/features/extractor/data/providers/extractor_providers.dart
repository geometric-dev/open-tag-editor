import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../tag_editor/data/providers/file_list_provider.dart';
import '../../../tag_editor/data/providers/selection_provider.dart';
import '../../../tag_editor/presentation/widgets/address_bar.dart';
import '../extractor_state_notifier.dart';
import '../models/extractor_state.dart';

/// Provider for the extractor state notifier.
///
/// This provider depends on the current file list and selection state.
/// Uses selected files if any are selected, otherwise uses all files.
final extractorStateProvider =
    StateNotifierProvider.autoDispose<ExtractorStateNotifier, ExtractorState>(
        (ref) {
  final allFiles = ref.watch(fileListProvider);
  final selection = ref.watch(selectionProvider);
  final undoRedo = ref.read(undoRedoProvider.notifier);
  final fileListNotifier = ref.read(fileListProvider.notifier);
  final rootFolder = ref.watch(loadedFolderPathProvider) ?? '';

  // Use selected files if any are selected, otherwise use all files.
  final files = selection.selectedPaths.isEmpty
      ? allFiles
      : allFiles
          .where((f) => selection.selectedPaths.contains(f.path))
          .toList();

  return ExtractorStateNotifier(
    files: files,
    rootFolder: rootFolder,
    undoRedoManager: undoRedo,
    fileListNotifier: fileListNotifier,
  );
});
