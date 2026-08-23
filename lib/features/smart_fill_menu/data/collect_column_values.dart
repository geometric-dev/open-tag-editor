import 'package:open_tag_editor/shared/models/audio_file.dart';

/// Collects unique non-empty tag values for a column across all files.
///
/// Returns values in the order they first appear in [files].
/// Excludes empty strings and whitespace-only strings (trimmed check).
/// Uses case-sensitive comparison for deduplication.
/// The original (untrimmed) value is used for deduplication and output.
List<String> collectColumnValues({
  required List<AudioFile> files,
  required String columnId,
}) {
  final seen = <String>{};
  final result = <String>[];

  for (final file in files) {
    final value = file.tags[columnId] ?? '';
    if (value.trim().isEmpty) continue;
    if (seen.add(value)) {
      result.add(value);
    }
  }

  return result;
}
