import '../../../shared/models/audio_file.dart';
import 'models/search_result.dart';
import 'models/track_file_match.dart';

/// Matches album tracks to selected audio files.
///
/// Uses two strategies:
/// 1. Order-based: when file count equals track count, match by position.
/// 2. Duration-based: match by duration similarity (±3 seconds tolerance).
class TrackMatcher {
  TrackMatcher._();

  /// Duration tolerance for matching in milliseconds (3 seconds).
  static const _toleranceMs = 3000;

  /// Attempts to auto-match tracks to files.
  ///
  /// If file count equals track count, uses order-based matching.
  /// Otherwise, falls back to duration-based matching.
  static List<TrackFileMatch> autoMatch({
    required List<TrackInfo> tracks,
    required List<AudioFile> files,
  }) {
    if (tracks.isEmpty) return [];

    if (tracks.length == files.length) {
      return _matchByOrder(tracks, files);
    }

    return _matchByDuration(tracks, files);
  }

  /// Matches tracks to files by position order.
  /// Assumes tracks[i] corresponds to files[i].
  static List<TrackFileMatch> _matchByOrder(
    List<TrackInfo> tracks,
    List<AudioFile> files,
  ) {
    return List.generate(tracks.length, (i) {
      return TrackFileMatch(
        track: tracks[i],
        file: files[i],
        confidence: MatchConfidence.exact,
      );
    },);
  }

  /// Matches tracks to files by duration similarity.
  /// Each track is matched to the closest-duration unmatched file
  /// within the tolerance window.
  static List<TrackFileMatch> _matchByDuration(
    List<TrackInfo> tracks,
    List<AudioFile> files,
  ) {
    final results = <TrackFileMatch>[];
    final unmatchedFiles = List<AudioFile?>.from(files);

    for (final track in tracks) {
      final trackDurationMs = track.durationMs;

      if (trackDurationMs == null) {
        // Can't match by duration without track duration
        results.add(TrackFileMatch(
          track: track,
          file: null,
          confidence: MatchConfidence.unmatched,
        ),);
        continue;
      }

      AudioFile? bestMatch;
      int bestDiff = _toleranceMs + 1;
      int bestIndex = -1;

      for (var i = 0; i < unmatchedFiles.length; i++) {
        final file = unmatchedFiles[i];
        if (file == null) continue;

        final fileDurationMs = ((file.duration ?? 0) * 1000).round();
        final diff = (trackDurationMs - fileDurationMs).abs();

        if (diff <= _toleranceMs && diff < bestDiff) {
          bestMatch = file;
          bestDiff = diff;
          bestIndex = i;
        }
      }

      if (bestMatch != null) {
        unmatchedFiles[bestIndex] = null; // Mark as used
        results.add(TrackFileMatch(
          track: track,
          file: bestMatch,
          confidence: MatchConfidence.duration,
        ),);
      } else {
        results.add(TrackFileMatch(
          track: track,
          file: null,
          confidence: MatchConfidence.unmatched,
        ),);
      }
    }

    return results;
  }
}
