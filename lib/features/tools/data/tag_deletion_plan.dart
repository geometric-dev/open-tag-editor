import '../../../../core/constants/tag_fields.dart';
import '../../../../shared/models/audio_file.dart';
import '../../../../shared/services/taglib/tag_property_mapper.dart';

/// How many of the selected files carry a given tag field.
///
/// Drives the partial indicator in the "Clear Fields..." dialog so the user
/// can tell a universally-populated field from one that is only on some of
/// the files.
class FieldUsage {
  const FieldUsage({
    required this.field,
    required this.presentCount,
    required this.fileCount,
  });

  /// App field name, e.g. `albumArtist`.
  final String field;

  /// Number of selected files that have a non-empty value for [field].
  final int presentCount;

  /// Total number of selected files.
  final int fileCount;

  /// Present on some but not all selected files.
  bool get isPartial => presentCount > 0 && presentCount < fileCount;

  /// Present on every selected file.
  bool get isUniversal => fileCount > 0 && presentCount == fileCount;

  /// Human-readable label for the dialog, falling back to the raw key for
  /// anything TagLib surfaced that the app has no enum entry for.
  String get label => displayNameFor(field);
}

/// A field inventory plus the exact per-file work a clear operation will do.
///
/// The plan is computed up front so confirmation and preview dialogs can
/// state real numbers ("will clear 4 fields across 3 files") instead of
/// guessing, and so the command that runs later cannot silently diverge
/// from what the user was shown.
class ClearPlan {
  const ClearPlan({
    required this.fieldsToClearByPath,
    required this.previousTags,
    required this.filesWithoutTags,
    required this.fileCount,
  });

  /// Empty plan: nothing to do.
  static const ClearPlan empty = ClearPlan(
    fieldsToClearByPath: {},
    previousTags: {},
    filesWithoutTags: 0,
    fileCount: 0,
  );

  /// Path -> fields that will be removed from that file.
  final Map<String, Set<String>> fieldsToClearByPath;

  /// Path -> complete tag map captured before clearing, for exact undo.
  final Map<String, Map<String, String>> previousTags;

  /// Number of selected files that carry no tags at all.
  final int filesWithoutTags;

  /// Total number of files considered.
  final int fileCount;

  int get affectedFileCount => fieldsToClearByPath.length;

  int get fieldCount =>
      fieldsToClearByPath.values.fold(0, (sum, fields) => sum + fields.length);

  bool get isEmpty => fieldsToClearByPath.isEmpty;
}

/// Returns the display name for an app field name.
String displayNameFor(String field) {
  for (final value in TagField.values) {
    if (value.name == field) return value.displayName;
  }
  return field;
}

/// Lists every field present across [files], with occurrence counts.
///
/// Only fields that actually carry a value are listed; the dialog is for
/// choosing what to remove, and offering a wall of empty fields would make
/// "Select All" destructive in a way the user cannot see. Ordering is
/// stable (enum declaration order, then unknown keys alphabetically) so the
/// dialog does not reshuffle between rebuilds.
List<FieldUsage> inventoryFields(Iterable<AudioFile> files) {
  final fileList = files.toList();
  if (fileList.isEmpty) return const [];

  final counts = <String, int>{};
  for (final file in fileList) {
    // Count distinct fields per file, not occurrences, so a multi-value
    // field joined into one string is not double-counted.
    final seen = <String>{};
    for (final entry in file.tags.entries) {
      if (entry.value.trim().isEmpty) continue;
      seen.add(entry.key);
    }
    for (final field in seen) {
      counts[field] = (counts[field] ?? 0) + 1;
    }
  }

  final known = <String>[];
  for (final value in TagField.values) {
    if (counts.containsKey(value.name)) known.add(value.name);
  }
  final unknown = counts.keys.where((k) => !known.contains(k)).toList()..sort();

  return [
    for (final field in [...known, ...unknown])
      FieldUsage(
        field: field,
        presentCount: counts[field]!,
        fileCount: fileList.length,
      ),
  ];
}

/// Builds the plan for removing tags from [files].
///
/// Passing `null` for [fields] clears every field the app manages
/// ("Clear All Tags"); passing a set clears only those fields, skipping any
/// file that does not have them so a no-op is never reported as a change.
ClearPlan planClear(Iterable<AudioFile> files, Set<String>? fields) {
  final fileList = files.toList();
  if (fileList.isEmpty) return ClearPlan.empty;

  final fieldsToClearByPath = <String, Set<String>>{};
  final previousTags = <String, Map<String, String>>{};
  var withoutTags = 0;

  for (final file in fileList) {
    final present = <String>{};
    for (final entry in file.tags.entries) {
      if (entry.value.trim().isEmpty) continue;
      if (fields != null && !fields.contains(entry.key)) continue;
      // Only fields TagLib can address can actually be cleared on disk;
      // offering a checkbox that silently does nothing is worse than not
      // listing the field.
      if (TagPropertyMapper.toTagLibKey(entry.key) == null) continue;
      present.add(entry.key);
    }

    if (file.tags.isEmpty) withoutTags++;
    if (present.isEmpty) continue;

    fieldsToClearByPath[file.path] = present;
    previousTags[file.path] = Map<String, String>.from(file.tags);
  }

  return ClearPlan(
    fieldsToClearByPath: fieldsToClearByPath,
    previousTags: previousTags,
    filesWithoutTags: withoutTags,
    fileCount: fileList.length,
  );
}
