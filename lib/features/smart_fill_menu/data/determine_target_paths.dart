import 'package:open_tag_editor/shared/models/audio_file.dart';

/// Determines which file paths should be affected by a fill action.
///
/// Returns all file paths when no subset is selected (zero selected or
/// all selected). Returns only selected paths otherwise.
List<String> determineTargetPaths({
  required Set<String> selectedPaths,
  required List<AudioFile> allFiles,
}) {
  if (selectedPaths.isEmpty || selectedPaths.length == allFiles.length) {
    return allFiles.map((f) => f.path).toList();
  }
  return selectedPaths.toList();
}
