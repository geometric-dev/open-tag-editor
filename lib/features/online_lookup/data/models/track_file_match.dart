import '../../../../shared/models/audio_file.dart';
import 'search_result.dart';

/// A proposed mapping between an album track and a local audio file.
class TrackFileMatch {
  const TrackFileMatch({
    required this.track,
    this.file,
    required this.confidence,
    this.score,
  });

  /// The album track from the online source.
  final TrackInfo track;

  /// The matched local audio file, or null if unmatched.
  final AudioFile? file;

  /// How confident the match is.
  final MatchConfidence confidence;

  /// The composite match score in [0.0, 1.0], null for order-based matches.
  final double? score;
}

/// Confidence level of a track-to-file match.
enum MatchConfidence {
  /// Matched by track number order (file count == track count).
  exact,

  /// High confidence multi-signal match (score ≥ 0.7).
  high,

  /// Medium confidence multi-signal match (score ≥ 0.4).
  medium,

  /// Low confidence multi-signal match (score < 0.4).
  low,

  /// Matched by duration similarity only (legacy, ±3 seconds).
  duration,

  /// No match found.
  unmatched,
}
