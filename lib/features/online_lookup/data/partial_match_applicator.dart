import '../../../shared/models/audio_file.dart';
import '../../../shared/services/tag_reader_service.dart';
import '../../tag_editor/data/providers/file_list_provider.dart';
import 'models/apply_result.dart';
import 'models/cover_art_result.dart';
import 'models/track_file_match.dart';

/// Applies metadata from a partial album match, distinguishing album-level
/// from track-level fields.
///
/// Album metadata (album, albumArtist, year, genre) is written to all
/// non-opted-out files. Track metadata (title, artist, discNumber) is written
/// only to files that have a track assignment. Track numbers use the total
/// file count as denominator (e.g. "3/16").
class PartialMatchApplicator {
  PartialMatchApplicator({
    required TagWriterService tagWriter,
    required FileListNotifier fileListNotifier,
    Set<String>? preservedFields,
  }) : _tagWriter = tagWriter,
       _fileListNotifier = fileListNotifier,
       _preservedFields = preservedFields ?? const {};

  final TagWriterService _tagWriter;
  final FileListNotifier _fileListNotifier;

  /// Tag fields an online lookup must never overwrite.
  ///
  /// Mirrors [MetadataApplicator]. A user who protects ReplayGain must get
  /// the same protection whichever apply path they use; without this, a
  /// partial match silently overwrote fields a full match would have kept.
  final Set<String> _preservedFields;

  ///
  /// These fields are written only to files that have a track assignment.
  static const Set<String> trackFields = {'title'};

  /// Applies metadata to files based on partial match results.
  ///
  /// - Album metadata is written to all non-opted-out files.
  /// - Track metadata is written only to files with a track assignment.
  /// - Track number uses [totalFileCount] as denominator.
  /// - Files in [optedOutPaths] are skipped entirely.
  Future<ApplyResult> apply({
    required List<TrackFileMatch> matches,
    required List<AudioFile> allFiles,
    required Set<String> selectedFields,
    required Set<String> optedOutPaths,
    required int totalFileCount,
    CoverArtResult? coverArt,
    bool applyCoverArt = false,
    String? albumTitle,
    String? albumArtist,
    String? year,
  }) async {
    final fileResults = <ApplyFileResult>[];
    var successCount = 0;
    var failureCount = 0;

    for (final file in allFiles) {
      if (optedOutPaths.contains(file.path)) {
        continue;
      }

      final tags = <String, String>{};

      // Album-level tags apply to all non-opted-out files.
      if (selectedFields.contains('album') &&
          albumTitle != null &&
          albumTitle.isNotEmpty) {
        tags['album'] = albumTitle;
      }
      if (selectedFields.contains('albumArtist') &&
          albumArtist != null &&
          albumArtist.isNotEmpty) {
        tags['albumArtist'] = albumArtist;
      }
      // Artist defaults to album artist for all files (same artist assumption).
      if (selectedFields.contains('artist') &&
          albumArtist != null &&
          albumArtist.isNotEmpty) {
        tags['artist'] = albumArtist;
      }
      if (selectedFields.contains('year') && year != null && year.isNotEmpty) {
        tags['year'] = year;
      }
      // Disc number is album-level — all files share the same disc.
      if (selectedFields.contains('discNumber')) {
        final discNum = _getDiscNumber(matches);
        if (discNum > 0) {
          tags['discNumber'] = discNum.toString();
        }
      }
      // Track total applies to all files (total file count).
      if (selectedFields.contains('trackNumber')) {
        tags['trackTotal'] = totalFileCount.toString();
      }

      // Find track assignment for this file.
      final match = _findMatchForFile(matches, file.path);

      // Track-level tags apply only to matched files.
      if (match != null) {
        final track = match.track;

        if (selectedFields.contains('title') && track.title.isNotEmpty) {
          tags['title'] = track.title;
        }
        // Override artist with track-specific artist if available.
        if (selectedFields.contains('artist') &&
            track.artist != null &&
            track.artist!.isNotEmpty) {
          tags['artist'] = track.artist!;
        }
        if (selectedFields.contains('trackNumber')) {
          tags['trackNumber'] = '${track.position}/$totalFileCount';
        }
      }

      // The preserved list is applied last so it wins over the per-field
      // selection above, exactly as in MetadataApplicator.
      if (_preservedFields.isNotEmpty) {
        tags.removeWhere((field, _) => _preservedFields.contains(field));
      }

      if (tags.isEmpty && !(applyCoverArt && coverArt != null)) {
        continue;
      }

      try {
        if (tags.isNotEmpty) {
          await _tagWriter.writeTags(file.path, tags);
        }

        if (applyCoverArt && coverArt != null) {
          await _tagWriter.writeAlbumArt(
            file.path,
            AlbumArtData(
              bytes: coverArt.imageBytes,
              mimeType: coverArt.mimeType,
            ),
          );
        }

        final updatedTags = Map<String, String>.from(file.tags)..addAll(tags);
        _fileListNotifier.updateFile(
          file.copyWith(
            tags: updatedTags,
            originalTags: Map<String, String>.unmodifiable(updatedTags),
            isModified: false,
          ),
        );

        fileResults.add(ApplyFileResult(path: file.path, success: true));
        successCount++;
      } catch (e) {
        fileResults.add(
          ApplyFileResult(path: file.path, success: false, error: e.toString()),
        );
        failureCount++;
      }
    }

    return ApplyResult(
      successCount: successCount,
      failureCount: failureCount,
      fileResults: fileResults,
    );
  }

  /// Finds the track match for a given file path, or null if unmatched.
  TrackFileMatch? _findMatchForFile(
    List<TrackFileMatch> matches,
    String filePath,
  ) {
    for (final match in matches) {
      if (match.file?.path == filePath) {
        return match;
      }
    }
    return null;
  }

  /// Extracts the disc number from the first matched track.
  ///
  /// All tracks in a partial match come from the same release, so they
  /// share the same disc number.
  int _getDiscNumber(List<TrackFileMatch> matches) {
    for (final match in matches) {
      if (match.file != null && match.confidence != MatchConfidence.unmatched) {
        return match.track.discNumber;
      }
    }
    return 0;
  }
}
