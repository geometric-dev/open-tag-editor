import '../../../shared/models/audio_file.dart';
import '../../../shared/services/tag_reader_service.dart';
import '../../tag_editor/data/providers/file_list_provider.dart';
import 'models/apply_result.dart';
import 'models/cover_art_result.dart';
import 'models/track_file_match.dart';

/// Applies retrieved metadata to audio files via TagWriterService.
///
/// Writes only the selected fields, handles partial failures,
/// and updates the file list state.
class MetadataApplicator {
  MetadataApplicator({
    required TagWriterService tagWriter,
    required FileListNotifier fileListNotifier,
  }) : _tagWriter = tagWriter,
       _fileListNotifier = fileListNotifier;

  final TagWriterService _tagWriter;
  final FileListNotifier _fileListNotifier;

  /// Applies selected fields from matched tracks to files.
  ///
  /// Only writes fields that are in [selectedFields].
  /// [albumTitle], [albumArtist], and [year] are album-level fields from the
  /// selected release — they apply uniformly to all matched files.
  /// Returns [ApplyResult] with per-file success/failure info.
  Future<ApplyResult> apply({
    required List<TrackFileMatch> matches,
    required Set<String> selectedFields,
    CoverArtResult? coverArt,
    bool applyCoverArt = false,
    String? albumTitle,
    String? albumArtist,
    String? year,
  }) async {
    final fileResults = <ApplyFileResult>[];
    var successCount = 0;
    var failureCount = 0;

    for (final match in matches) {
      if (match.file == null || match.confidence == MatchConfidence.unmatched) {
        continue;
      }

      final file = match.file!;
      final tags = _buildTagMap(
        match,
        selectedFields,
        albumTitle: albumTitle,
        albumArtist: albumArtist,
        year: year,
      );

      if (tags.isEmpty && !(applyCoverArt && coverArt != null)) {
        continue;
      }

      try {
        // Write tags if any fields selected
        if (tags.isNotEmpty) {
          await _tagWriter.writeTags(file.path, tags);
        }

        // Write cover art if selected
        if (applyCoverArt && coverArt != null) {
          await _tagWriter.writeAlbumArt(
            file.path,
            AlbumArtData(
              bytes: coverArt.imageBytes,
              mimeType: coverArt.mimeType,
            ),
          );
        }

        // Update file in the list — tags are now on disk so update
        // originalTags to reflect the new on-disk state.
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

  /// Builds a tag map from the track info, including only selected fields.
  ///
  /// Album-level fields ([albumTitle], [albumArtist], [year]) come from the
  /// selected release and are applied uniformly to all files.
  Map<String, String> _buildTagMap(
    TrackFileMatch match,
    Set<String> selectedFields, {
    String? albumTitle,
    String? albumArtist,
    String? year,
  }) {
    final track = match.track;
    final tags = <String, String>{};

    if (selectedFields.contains('title') && track.title.isNotEmpty) {
      tags['title'] = track.title;
    }
    if (selectedFields.contains('artist') && track.artist != null) {
      tags['artist'] = track.artist!;
    }
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
    if (selectedFields.contains('year') && year != null && year.isNotEmpty) {
      tags['year'] = year;
    }
    if (selectedFields.contains('trackNumber')) {
      tags['trackNumber'] = track.position.toString();
    }
    if (selectedFields.contains('discNumber') && track.discNumber > 0) {
      tags['discNumber'] = track.discNumber.toString();
    }

    return tags;
  }
}
