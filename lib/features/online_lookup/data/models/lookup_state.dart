import 'cover_art_result.dart';
import 'search_result.dart';
import 'track_file_match.dart';

/// Immutable state for the lookup workflow.
class LookupState {
  const LookupState({
    this.status = LookupStatus.idle,
    this.searchResults = const [],
    this.selectedResult,
    this.trackListing = const [],
    this.matches = const [],
    this.coverArt,
    this.coverArtLoading = false,
    this.error,
    this.fingerprintProgress,
    this.queueLength = 0,
  });

  /// Current workflow status.
  final LookupStatus status;

  /// Search results from the last query.
  final List<SearchResult> searchResults;

  /// The currently selected search result.
  final SearchResult? selectedResult;

  /// Track listing for the selected result.
  final List<TrackInfo> trackListing;

  /// Track-to-file matching results.
  final List<TrackFileMatch> matches;

  /// Cover art for the selected release.
  final CoverArtResult? coverArt;

  /// Whether cover art is currently being fetched.
  final bool coverArtLoading;

  /// Error message, if any.
  final String? error;

  /// Fingerprint generation progress.
  final FingerprintProgress? fingerprintProgress;

  /// Number of requests in the rate limiter queue.
  final int queueLength;

  /// Creates a copy with updated fields.
  LookupState copyWith({
    LookupStatus? status,
    List<SearchResult>? searchResults,
    SearchResult? selectedResult,
    List<TrackInfo>? trackListing,
    List<TrackFileMatch>? matches,
    CoverArtResult? coverArt,
    bool? coverArtLoading,
    String? error,
    FingerprintProgress? fingerprintProgress,
    int? queueLength,
  }) {
    return LookupState(
      status: status ?? this.status,
      searchResults: searchResults ?? this.searchResults,
      selectedResult: selectedResult ?? this.selectedResult,
      trackListing: trackListing ?? this.trackListing,
      matches: matches ?? this.matches,
      coverArt: coverArt ?? this.coverArt,
      coverArtLoading: coverArtLoading ?? this.coverArtLoading,
      error: error ?? this.error,
      fingerprintProgress: fingerprintProgress ?? this.fingerprintProgress,
      queueLength: queueLength ?? this.queueLength,
    );
  }
}

/// Status of the lookup workflow.
enum LookupStatus {
  /// No operation in progress.
  idle,

  /// Searching for releases.
  searching,

  /// Loading track listing for a selected release.
  loadingTracks,

  /// Generating fingerprints and identifying files.
  fingerprinting,

  /// Applying metadata to files.
  applying,

  /// Operation completed successfully.
  complete,

  /// An error occurred.
  error,
}

/// Progress of fingerprint generation.
class FingerprintProgress {
  const FingerprintProgress({
    required this.completed,
    required this.total,
  });

  /// Number of files processed so far.
  final int completed;

  /// Total number of files to process.
  final int total;
}
