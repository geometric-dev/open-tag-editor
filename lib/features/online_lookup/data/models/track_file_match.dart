import '../../../../shared/models/audio_file.dart';
import 'search_result.dart';

/// A proposed mapping between an album track and a local audio file.
class TrackFileMatch {
  const TrackFileMatch({
    required this.track,
    this.file,
    required this.confidence,
  });

  /// The album track from the online source.
  final TrackInfo track;

  /// The matched local audio file, or null if unmatched.
  final AudioFile? file;

  /// How confident the match is.
  final MatchConfidence confidence;
}

/// Confidence level of a track-to-file match.
enum MatchConfidence {
  /// Matched by track number order (file count == track count).
  exact,

  /// Matched by duration similarity (within ±3 seconds).
  duration,

  /// No match found.
  unmatched,
}
