import '../../data/commands/tag_edit_command.dart';
import '../../../../shared/models/audio_file.dart';
import '../../../tag_editor/data/providers/file_list_provider.dart';

/// Builds a [TagEditCommand] for an inline edit.
///
/// Returns null if the new value equals the original (no-op) for single-file
/// edits. For batch edits, always creates a command.
TagEditCommand? buildTagEditCommand({
  required FileListNotifier fileListNotifier,
  required List<String> filePaths,
  required String columnId,
  required String newValue,
  required List<AudioFile> allFiles,
}) {
  // Gather previous values for all affected files
  final previousValues = <String, String?>{};
  for (final file in allFiles) {
    if (filePaths.contains(file.path)) {
      previousValues[file.path] = file.tags[columnId];
    }
  }

  // Check if this is a no-op for single file edits
  if (filePaths.length == 1) {
    final prev = previousValues[filePaths.first];
    if ((prev ?? '') == newValue) return null;
  }

  return TagEditCommand(
    fileListNotifier: fileListNotifier,
    filePaths: filePaths,
    fieldName: columnId,
    newValue: newValue,
    previousValues: previousValues,
  );
}
