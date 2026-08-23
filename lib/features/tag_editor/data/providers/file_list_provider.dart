import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../shared/models/audio_file.dart';

/// Holds the list of currently loaded audio files.
final fileListProvider =
    StateNotifierProvider<FileListNotifier, List<AudioFile>>((ref) {
  return FileListNotifier();
});

/// Tracks which files are currently selected (legacy, use editor_state_provider).
final selectedFilesLegacyProvider = StateProvider<Set<String>>((ref) => {});

/// Filter text for the file list.
final fileFilterProvider = StateProvider<String>((ref) => '');

/// Filtered file list based on the search filter.
final filteredFileListProvider = Provider<List<AudioFile>>((ref) {
  final files = ref.watch(fileListProvider);
  final filter = ref.watch(fileFilterProvider).toLowerCase();

  if (filter.isEmpty) return files;

  return files.where((file) {
    return file.filename.toLowerCase().contains(filter) ||
        file.tags.values.any((v) => v.toLowerCase().contains(filter));
  }).toList();
});

class FileListNotifier extends StateNotifier<List<AudioFile>> {
  FileListNotifier() : super([]);

  /// Public access to the current file list for commands.
  List<AudioFile> get currentFiles => state;

  /// Adds files to the list.
  void addFiles(List<AudioFile> files) {
    // Avoid duplicates by path
    final existingPaths = state.map((f) => f.path).toSet();
    final newFiles = files.where((f) => !existingPaths.contains(f.path));
    state = [...state, ...newFiles];
  }

  /// Removes files from the list by path.
  void removeFiles(Set<String> paths) {
    state = state.where((f) => !paths.contains(f.path)).toList();
  }

  /// Clears all loaded files.
  void clear() {
    state = [];
  }

  /// Updates a single file's data (e.g., after tag edit).
  void updateFile(AudioFile updatedFile) {
    state = [
      for (final file in state)
        if (file.path == updatedFile.path) updatedFile else file,
    ];
  }

  /// Updates multiple files (e.g., after batch edit).
  void updateFiles(List<AudioFile> updatedFiles) {
    final updateMap = {for (final f in updatedFiles) f.path: f};
    state = [
      for (final file in state) updateMap[file.path] ?? file,
    ];
  }
}
