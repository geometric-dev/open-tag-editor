import '../../../../shared/models/audio_file.dart';
import 'search_result.dart';
import 'track_file_match.dart';

/// Represents a file row in the partial match apply panel.
class PartialMatchFileEntry {
  /// Creates a [PartialMatchFileEntry].
  const PartialMatchFileEntry({
    required this.file,
    this.matchedTrack,
    this.confidence,
    this.score,
    this.isOptedOut = false,
  });

  /// The local audio file.
  final AudioFile file;

  /// The matched track, or null if unmatched.
  final TrackInfo? matchedTrack;

  /// Match confidence level.
  final MatchConfidence? confidence;

  /// Composite match score in [0.0, 1.0].
  final double? score;

  /// Whether the user has opted this file out of metadata application.
  final bool isOptedOut;

  /// Whether this file has a track assignment.
  bool get isMatched => matchedTrack != null;

  /// Creates a copy with updated fields.
  ///
  /// Use [clearMatchedTrack], [clearConfidence], or [clearScore] to
  /// explicitly set the corresponding nullable field to null.
  PartialMatchFileEntry copyWith({
    AudioFile? file,
    TrackInfo? matchedTrack,
    bool clearMatchedTrack = false,
    MatchConfidence? confidence,
    bool clearConfidence = false,
    double? score,
    bool clearScore = false,
    bool? isOptedOut,
  }) {
    return PartialMatchFileEntry(
      file: file ?? this.file,
      matchedTrack: clearMatchedTrack
          ? null
          : (matchedTrack ?? this.matchedTrack),
      confidence: clearConfidence ? null : (confidence ?? this.confidence),
      score: clearScore ? null : (score ?? this.score),
      isOptedOut: isOptedOut ?? this.isOptedOut,
    );
  }
}
