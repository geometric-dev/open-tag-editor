import '../../../shared/models/audio_file.dart';
import 'filename_parser.dart';
import 'fuzzy_matcher.dart';
import 'models/search_result.dart';
import 'models/track_file_match.dart';

/// Matches album tracks to selected audio files using multi-signal scoring.
///
/// Uses two strategies:
/// 1. Order-based: when file count equals track count, match by position.
/// 2. Score-based: builds a composite score matrix (track number, title
///    similarity, duration proximity) and uses the Hungarian algorithm to
///    find the globally optimal assignment.
class TrackMatcher {
  TrackMatcher._();

  /// Duration tolerance for matching in milliseconds (3 seconds).
  static const _toleranceMs = 3000;

  /// Weight for the track number signal in composite score.
  static const double trackNumberWeight = 0.5;

  /// Weight for the title similarity signal in composite score.
  static const double titleWeight = 0.3;

  /// Weight for the duration proximity signal in composite score.
  static const double durationWeight = 0.2;

  /// Minimum similarity threshold below which title signal is ignored.
  static const double minTitleSimilarity = 0.4;

  /// Short title length threshold for weight reduction.
  static const int shortTitleLength = 3;

  /// Duration tolerance in milliseconds (3 seconds).
  static const int durationToleranceMs = 3000;

  /// Attempts to auto-match tracks to files using multi-signal scoring.
  ///
  /// If file count equals track count, uses order-based matching.
  /// Otherwise, builds a score matrix and finds optimal assignment via
  /// the Hungarian algorithm.
  static List<TrackFileMatch> autoMatch({
    required List<TrackInfo> tracks,
    required List<AudioFile> files,
  }) {
    if (tracks.isEmpty) return [];

    if (tracks.length == files.length) {
      return _matchByOrder(tracks, files);
    }

    return _matchByScore(tracks, files);
  }

  /// Computes the composite match score for a single file-track pair.
  ///
  /// Returns a score in [0.0, 1.0] combining track number, title similarity,
  /// and duration proximity signals with configurable weights.
  static double computeScore({
    required AudioFile file,
    required TrackInfo track,
  }) {
    // 1. Track number signal (0.0 or 1.0)
    final extractedTrackNumber = FilenameParser.extractTrackNumber(
      file.filename,
    );
    final trackNumberSignal =
        (extractedTrackNumber != null && extractedTrackNumber == track.position)
        ? 1.0
        : 0.0;

    // 2. Title signal (0.0–1.0)
    final extractedTitle = FilenameParser.extractTitle(file.filename);
    final rawTitleSimilarity = FuzzyMatcher.similarity(
      extractedTitle,
      track.title,
    );
    final titleSignal = rawTitleSimilarity < minTitleSimilarity
        ? 0.0
        : rawTitleSimilarity;

    // 3. Duration signal (0.0–1.0)
    final double durationSignal;
    final fileDurationMs = ((file.duration ?? 0) * 1000).round();
    if (file.duration == null || track.durationMs == null) {
      durationSignal = 0.0;
    } else {
      final diffMs = (fileDurationMs - track.durationMs!).abs();
      durationSignal = (1.0 - (diffMs / durationToleranceMs)).clamp(0.0, 1.0);
    }

    // 4. Effective title weight (halved for short titles)
    final effectiveTitleWeight = track.title.length <= shortTitleLength
        ? titleWeight * 0.5
        : titleWeight;

    // 5. Composite score
    return (trackNumberWeight * trackNumberSignal) +
        (effectiveTitleWeight * titleSignal) +
        (durationWeight * durationSignal);
  }

  /// Matches tracks to files by position order.
  ///
  /// Sorts files by track number tag (if available) or filename before
  /// matching, so the result is correct regardless of selection order.
  static List<TrackFileMatch> _matchByOrder(
    List<TrackInfo> tracks,
    List<AudioFile> files,
  ) {
    final sortedFiles = List<AudioFile>.from(files)
      ..sort((a, b) {
        final aTrack = int.tryParse(a.tags['trackNumber'] ?? '') ?? 0;
        final bTrack = int.tryParse(b.tags['trackNumber'] ?? '') ?? 0;
        if (aTrack != bTrack) return aTrack.compareTo(bTrack);
        return a.filename.compareTo(b.filename);
      });

    return List.generate(tracks.length, (i) {
      return TrackFileMatch(
        track: tracks[i],
        file: sortedFiles[i],
        confidence: MatchConfidence.exact,
      );
    });
  }

  /// Matches tracks to files using the Hungarian algorithm to find the
  /// optimal assignment that maximises total composite score.
  ///
  /// Builds a score matrix, converts to a cost matrix for minimisation,
  /// pads to square if needed, and extracts the optimal assignment.
  static List<TrackFileMatch> _matchByScore(
    List<TrackInfo> tracks,
    List<AudioFile> files,
  ) {
    final numTracks = tracks.length;
    final numFiles = files.length;

    // Build score matrix: scores[trackIndex][fileIndex]
    final scores = List.generate(
      numTracks,
      (i) => List.generate(
        numFiles,
        (j) => computeScore(file: files[j], track: tracks[i]),
      ),
    );

    // Convert to cost matrix for minimisation: cost = 1.0 - score
    final n = numTracks > numFiles ? numTracks : numFiles;
    final cost = List.generate(
      n,
      (i) => List.generate(n, (j) {
        if (i < numTracks && j < numFiles) {
          return 1.0 - scores[i][j];
        }
        // Dummy rows/columns have zero cost (won't affect real assignments)
        return 0.0;
      }),
    );

    // Run Hungarian algorithm on the square cost matrix
    final assignment = _hungarian(cost);

    // Extract results for each track
    final results = <TrackFileMatch>[];
    for (var i = 0; i < numTracks; i++) {
      final assignedFile = assignment[i];
      if (assignedFile < numFiles) {
        final score = scores[i][assignedFile];
        results.add(
          TrackFileMatch(
            track: tracks[i],
            file: files[assignedFile],
            confidence: _confidenceFromScore(score),
            score: score,
          ),
        );
      } else {
        // Assigned to a dummy column — no real file available
        results.add(
          TrackFileMatch(
            track: tracks[i],
            file: null,
            confidence: MatchConfidence.unmatched,
            score: 0.0,
          ),
        );
      }
    }

    return results;
  }

  /// Determines the confidence level from a composite score.
  static MatchConfidence _confidenceFromScore(double score) {
    if (score >= 0.7) return MatchConfidence.high;
    if (score >= 0.4) return MatchConfidence.medium;
    return MatchConfidence.low;
  }

  /// Implements the Hungarian algorithm (Kuhn-Munkres) for the assignment
  /// problem on a square cost matrix.
  ///
  /// Returns a list where `result[i]` is the column assigned to row `i`.
  /// The algorithm finds the minimum-cost assignment in O(n³) time.
  static List<int> _hungarian(List<List<double>> cost) {
    final n = cost.length;
    if (n == 0) return [];

    // u[i] = potential for row i, v[j] = potential for column j
    // p[j] = row assigned to column j (0 means unassigned, using 1-indexed)
    // way[j] = column that led to column j in the augmenting path
    final u = List.filled(n + 1, 0.0);
    final v = List.filled(n + 1, 0.0);
    final p = List.filled(n + 1, 0);
    final way = List.filled(n + 1, 0);

    for (var i = 1; i <= n; i++) {
      // Start augmenting path from row i
      p[0] = i;
      var j0 = 0;
      final minv = List.filled(n + 1, double.infinity);
      final used = List.filled(n + 1, false);

      do {
        used[j0] = true;
        final i0 = p[j0];
        var delta = double.infinity;
        var j1 = 0;

        for (var j = 1; j <= n; j++) {
          if (used[j]) continue;
          final cur = cost[i0 - 1][j - 1] - u[i0] - v[j];
          if (cur < minv[j]) {
            minv[j] = cur;
            way[j] = j0;
          }
          if (minv[j] < delta) {
            delta = minv[j];
            j1 = j;
          }
        }

        for (var j = 0; j <= n; j++) {
          if (used[j]) {
            u[p[j]] += delta;
            v[j] -= delta;
          } else {
            minv[j] -= delta;
          }
        }

        j0 = j1;
      } while (p[j0] != 0);

      // Update assignment along the augmenting path
      do {
        final j1 = way[j0];
        p[j0] = p[j1];
        j0 = j1;
      } while (j0 != 0);
    }

    // Convert to 0-indexed: result[row] = column
    final result = List.filled(n, 0);
    for (var j = 1; j <= n; j++) {
      result[p[j] - 1] = j - 1;
    }
    return result;
  }

  /// Matches tracks to files by duration similarity.
  ///
  /// Each track is matched to the closest-duration unmatched file
  /// within the tolerance window.
  // ignore: unused_element
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
        results.add(
          TrackFileMatch(
            track: track,
            file: null,
            confidence: MatchConfidence.unmatched,
          ),
        );
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
        results.add(
          TrackFileMatch(
            track: track,
            file: bestMatch,
            confidence: MatchConfidence.duration,
          ),
        );
      } else {
        results.add(
          TrackFileMatch(
            track: track,
            file: null,
            confidence: MatchConfidence.unmatched,
          ),
        );
      }
    }

    return results;
  }
}
