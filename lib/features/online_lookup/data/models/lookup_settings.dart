import 'package:equatable/equatable.dart';

import '../models/search_result.dart';

/// Persisted settings for online metadata lookup.
class LookupSettings extends Equatable {
  const LookupSettings({
    this.discogsToken = '',
    this.fpcalcPath = '',
    this.defaultSource = SearchSource.musicBrainz,
    this.autoFetchCoverArt = true,
  });

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

  @override
  List<Object?> get props => [
        discogsToken,
        fpcalcPath,
        defaultSource,
        autoFetchCoverArt,
      ];

  /// Creates a copy with updated fields.
  LookupSettings copyWith({
    String? discogsToken,
    String? fpcalcPath,
    SearchSource? defaultSource,
    bool? autoFetchCoverArt,
  }) {
    return LookupSettings(
      discogsToken: discogsToken ?? this.discogsToken,
      fpcalcPath: fpcalcPath ?? this.fpcalcPath,
      defaultSource: defaultSource ?? this.defaultSource,
      autoFetchCoverArt: autoFetchCoverArt ?? this.autoFetchCoverArt,
    );
  }
}
