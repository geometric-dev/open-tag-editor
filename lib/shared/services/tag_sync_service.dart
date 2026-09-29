import '../models/audio_file.dart';
import 'id3v1_codec.dart';
import 'tag_reader_service.dart';

export 'id3v1_codec.dart' show Id3v1Codec;

/// Result of one file's tag synchronization.
class TagSyncFileResult {
  const TagSyncFileResult({
    required this.path,
    required this.success,
    this.error,
  });

  final String path;
  final bool success;
  final String? error;
}

/// Summary of a batch sync operation.
class TagSyncResult {
  const TagSyncResult({
    required this.updatedCount,
    required this.skippedCount,
    required this.failures,
  });

  final int updatedCount;
  final int skippedCount;
  final List<TagSyncFileResult> failures;

  bool get allSuccess => failures.isEmpty;
}

/// Synchronizes ID3v1 and ID3v2 tag data for MP3 files, reproducing
/// Tag&Rename's "Tags synchronization wizard".
///
/// - [syncToId3v1]: the app's visible tags (ID3v2 source of truth) are
///   rewritten into the trailing ID3v1 block, replacing or appending it.
/// - [syncFromId3v1]: raw ID3v1 values fill EMPTY fields of ID3v2
///   (fill-empty semantics so legacy data never clobbers richer v2 tags).
///
/// Non-MP3 files are always reported as skipped.
class TagSyncService {
  /// Creates a [TagSyncService] with the given writer.
  TagSyncService({required TagWriterService tagWriter})
    : _tagWriter = tagWriter;

  final TagWriterService _tagWriter;

  /// Copies current (v2) tags down into each file's ID3v1 block.
  Future<TagSyncResult> syncToId3v1(List<AudioFile> files) async {
    return _forEachMp3(files, (file) {
      Id3v1Codec.writeToFile(file.path, file.tags);
      return true;
    });
  }

  /// Fills empty v2 fields from each file's existing ID3v1 block.
  ///
  /// Writes only the delta through [TagWriterService] so backups,
  /// atomicity, validation and timestamp policy all still apply. Files
  /// whose v1 adds nothing new count as skipped.
  Future<TagSyncResult> syncFromId3v1(List<AudioFile> files) async {
    var updated = 0;
    var skipped = 0;
    final failures = <TagSyncFileResult>[];

    for (final file in files) {
      if (!file.path.toLowerCase().endsWith('.mp3')) {
        skipped++;
        continue;
      }
      try {
        final v1 = Id3v1Codec.readFromFile(file.path);
        if (v1 == null) {
          skipped++;
          continue;
        }

        final delta = <String, String>{};
        for (final entry in v1.entries) {
          final current = file.tags[entry.key];
          if ((current == null || current.isEmpty) && entry.value.isNotEmpty) {
            delta[entry.key] = entry.value;
          }
        }

        if (delta.isEmpty) {
          skipped++;
          continue;
        }

        await _tagWriter.writeTags(file.path, delta);
        updated++;
      } catch (e) {
        failures.add(
          TagSyncFileResult(
            path: file.path,
            success: false,
            error: e.toString(),
          ),
        );
      }
    }

    return TagSyncResult(
      updatedCount: updated,
      skippedCount: skipped,
      failures: failures,
    );
  }

  Future<TagSyncResult> _forEachMp3(
    List<AudioFile> files,
    bool Function(AudioFile) action,
  ) async {
    var updated = 0;
    var skipped = 0;
    final failures = <TagSyncFileResult>[];

    for (final file in files) {
      if (!file.path.toLowerCase().endsWith('.mp3')) {
        skipped++;
        continue;
      }
      try {
        if (action(file)) {
          updated++;
        } else {
          skipped++;
        }
      } catch (e) {
        failures.add(
          TagSyncFileResult(
            path: file.path,
            success: false,
            error: e.toString(),
          ),
        );
      }
    }

    return TagSyncResult(
      updatedCount: updated,
      skippedCount: skipped,
      failures: failures,
    );
  }
}
