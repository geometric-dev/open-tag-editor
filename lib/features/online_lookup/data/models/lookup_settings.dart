import 'package:equatable/equatable.dart';

import '../models/search_result.dart';

/// Groups of fields a user is likely to want preserved together.
///
/// Offered in the settings UI so the common cases are one click instead of
/// hunting through a checkbox list.
enum PreservedFieldPreset {
  replayGain(
    'ReplayGain',
    'Scanner-calculated loudness data. A lookup result can never regenerate '
        'it, so overwriting loses real work.',
    {
      'replayGainTrackGain',
      'replayGainTrackPeak',
      'replayGainAlbumGain',
      'replayGainAlbumPeak',
    },
  ),
  ratings(
    'Ratings & Mood',
    'Your own judgement of a track, which online data has no opinion about.',
    {'rating', 'mood'},
  ),
  personalNotes(
    'Personal notes',
    'Free text you wrote yourself, such as a comment or grouping.',
    {'comment', 'grouping', 'lyricist', 'publisher'},
  ),
  identifiers(
    'Identifiers',
    'Cataloguing data a release page may report differently to your '
        'library convention.',
    {'isrc', 'catalogNumber', 'label'},
  );

  const PreservedFieldPreset(this.label, this.description, this.fields);

  final String label;
  final String description;
  final Set<String> fields;
}

/// Persisted settings for online metadata lookup.
class LookupSettings extends Equatable {
  const LookupSettings({
    this.discogsToken = '',
    this.fpcalcPath = '',
    this.defaultSource = SearchSource.musicBrainz,
    this.autoFetchCoverArt = true,
    this.preservedFields = defaultPreservedFields,
  });

  /// Tag fields that an online lookup must never overwrite.
  ///
  /// Defaults to ReplayGain. That is the one case where an apply is
  /// unambiguously destructive: the lookup result cannot regenerate
  /// loudness data, so overwriting it loses work that took a scanner to
  /// produce and is silently wrong afterwards.
  final Set<String> preservedFields;

  /// The out-of-the-box preserved set.
  static const Set<String> defaultPreservedFields = {
    'replayGainTrackGain',
    'replayGainTrackPeak',
    'replayGainAlbumGain',
    'replayGainAlbumPeak',
  };

  /// Discogs personal access token.
  final String discogsToken;

  /// Path to the fpcalc binary.
  final String fpcalcPath;

  /// Default search source.
  final SearchSource defaultSource;

  /// Whether to auto-fetch cover art when a release is selected.
  final bool autoFetchCoverArt;

  /// Whether Discogs is configured (token is non-empty).
  bool get isDiscogsConfigured => discogsToken.isNotEmpty;

  /// Whether [field] must survive an online apply.
  bool preserves(String field) => preservedFields.contains(field);

  @override
  List<Object?> get props => [
    discogsToken,
    fpcalcPath,
    defaultSource,
    autoFetchCoverArt,
    // Set is unordered, so compare the sorted view to keep equality stable.
    preservedFields.toList()..sort(),
  ];

  /// Creates a copy with updated fields.
  LookupSettings copyWith({
    String? discogsToken,
    String? fpcalcPath,
    SearchSource? defaultSource,
    bool? autoFetchCoverArt,
    Set<String>? preservedFields,
  }) {
    return LookupSettings(
      discogsToken: discogsToken ?? this.discogsToken,
      fpcalcPath: fpcalcPath ?? this.fpcalcPath,
      defaultSource: defaultSource ?? this.defaultSource,
      autoFetchCoverArt: autoFetchCoverArt ?? this.autoFetchCoverArt,
      preservedFields: preservedFields ?? this.preservedFields,
    );
  }
}
