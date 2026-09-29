import 'package:flutter_riverpod/legacy.dart';

import '../../../../shared/models/audio_file.dart';

/// Holds the list of currently loaded audio files.
final fileListProvider =
    StateNotifierProvider<FileListNotifier, List<AudioFile>>((ref) {
      return FileListNotifier();
    });

/// Filter text for the file list.
final fileFilterProvider = StateProvider<String>((ref) => '');

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
    state = [for (final file in state) updateMap[file.path] ?? file];
  }
}
