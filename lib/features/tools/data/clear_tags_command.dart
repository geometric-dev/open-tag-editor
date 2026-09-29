import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../shared/models/audio_file.dart';
import '../../tag_editor/data/providers/file_list_provider.dart';
import 'tag_deletion_plan.dart';

/// Undoable removal of tag fields from one or more files.
///
/// The clear is expressed as an in-memory tag change rather than a direct
/// disk write, so it flows through the single save path: `AudioFile
/// .modifiedTags` turns a field that disappeared between `originalTags` and
/// `tags` into an empty value, and the writer passes that as `nullptr` to
/// TagLib. That keeps backups, atomic writes, validation and the
/// write-backgrounds-off-the-UI-thread behaviour identical to an ordinary
/// edit, and it means a clear is still only a *pending* change until the
/// user saves.
class ClearTagsCommand implements UndoableCommand {
  ClearTagsCommand({
    required this.fileListNotifier,
    required this.plan,
    this.description = 'Clear tags',
  });

  final FileListNotifier fileListNotifier;
  final ClearPlan plan;

  @override
  final String description;

  @override
  void execute() {
    final updated = <AudioFile>[];
    for (final file in fileListNotifier.currentFiles) {
      final fields = plan.fieldsToClearByPath[file.path];
      if (fields == null) continue;

      final newTags = Map<String, String>.from(file.tags);
      var changed = false;
      for (final field in fields) {
        if (newTags.remove(field) != null) changed = true;
      }
      if (!changed) continue;
      updated.add(file.copyWith(tags: newTags, isModified: true));
    }
    if (updated.isNotEmpty) fileListNotifier.updateFiles(updated);
  }

  @override
  void undo() {
    final updated = <AudioFile>[];
    for (final file in fileListNotifier.currentFiles) {
      final fields = plan.fieldsToClearByPath[file.path];
      final previous = plan.previousTags[file.path];
      if (fields == null || previous == null) continue;

      // Restore only the fields this command cleared. Restoring the whole
      // previous map would silently discard any edit the user made after
      // the clear, which is a real data-loss path rather than a hypothetical.
      final newTags = Map<String, String>.from(file.tags);
      var changed = false;
      for (final field in fields) {
        final value = previous[field];
        if (value == null) continue;
        if (newTags[field] == value) continue;
        newTags[field] = value;
        changed = true;
      }
      if (!changed) continue;

      final stillModified = file.differsFromOriginal(newTags);
      updated.add(file.copyWith(tags: newTags, isModified: stillModified));
    }
    if (updated.isNotEmpty) fileListNotifier.updateFiles(updated);
  }
}
