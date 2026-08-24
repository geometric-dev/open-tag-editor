import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../shared/models/audio_file.dart';
import '../../tag_editor/data/providers/file_list_provider.dart';

/// Undoable command applying per-file tag deltas (field -> new value).
///
/// Unlike [BatchTagEditCommand] which pushes one uniform value-set to every
/// file, this carries a distinct delta per file — what field-transform tools
/// ("The Artist" <-> "Artist, The", future case/normalization tools) need.
class TagTransformCommand implements UndoableCommand {
  TagTransformCommand({
    required this.fileListNotifier,
    required this.deltas,
    required this.previousTags,
    required this.description,
  });

  final FileListNotifier fileListNotifier;

  /// Map of file path -> {field: newValue} for fields that change.
  final Map<String, Map<String, String>> deltas;

  /// Full previous tag maps keyed by file path (for exact undo).
  final Map<String, Map<String, String>> previousTags;

  @override
  final String description;

  @override
  void execute() {
    final updated = <AudioFile>[];
    for (final file in fileListNotifier.currentFiles) {
      final delta = deltas[file.path];
      if (delta == null || delta.isEmpty) continue;

      final newTags = Map<String, String>.from(file.tags);
      var changed = false;
      for (final entry in delta.entries) {
        if ((newTags[entry.key] ?? '') == entry.value) continue;
        changed = true;
        newTags[entry.key] = entry.value;
      }
      if (changed) {
        updated.add(file.copyWith(tags: newTags, isModified: true));
      }
    }
    if (updated.isNotEmpty) fileListNotifier.updateFiles(updated);
  }

  @override
  void undo() {
    // Only files this command touched participate in undo.
    final updated = <AudioFile>[];
    for (final entry in deltas.entries) {
      final prev = previousTags[entry.key];
      if (prev == null) continue;

      AudioFile? file;
      for (final candidate in fileListNotifier.currentFiles) {
        if (candidate.path == entry.key) {
          file = candidate;
          break;
        }
      }
      if (file == null) continue;

      final original = file.originalTags;
      final stillModified = original == null || !_mapsEqual(prev, original);
      updated.add(
        file.copyWith(
          tags: Map<String, String>.from(prev),
          isModified: stillModified,
        ),
      );
    }
    if (updated.isNotEmpty) fileListNotifier.updateFiles(updated);
  }

  bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
