import '../../../../shared/models/audio_file.dart';
import 'cover_art_result.dart';
import 'search_result.dart';
import 'track_file_match.dart';

/// Sentinel value used by [LookupState.copyWith] to distinguish between
/// "not provided" and "explicitly set to null".
const _sentinel = Object();

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
    this.isPartialMatch = false,
    this.optedOutPaths = const {},
    this.allSelectedFiles = const [],
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

  /// Whether this is a partial match (album tracks < selected files).
  final bool isPartialMatch;

  /// Set of file paths the user has opted out of metadata application.
  final Set<String> optedOutPaths;

  /// Full list of selected files (for unmatched display in partial mode).
  final List<AudioFile> allSelectedFiles;

  /// Creates a copy with updated fields.
  ///
  /// Nullable fields use a sentinel default so that passing `null` explicitly
  /// clears the value, while omitting the parameter preserves the current one.
  LookupState copyWith({
    LookupStatus? status,
    List<SearchResult>? searchResults,
    Object? selectedResult = _sentinel,
    List<TrackInfo>? trackListing,
    List<TrackFileMatch>? matches,
    Object? coverArt = _sentinel,
    bool? coverArtLoading,
    Object? error = _sentinel,
    Object? fingerprintProgress = _sentinel,
    int? queueLength,
    bool? isPartialMatch,
    Set<String>? optedOutPaths,
    List<AudioFile>? allSelectedFiles,
  }) {
    return LookupState(
      status: status ?? this.status,
      searchResults: searchResults ?? this.searchResults,
      selectedResult: selectedResult == _sentinel
          ? this.selectedResult
          : selectedResult as SearchResult?,
      trackListing: trackListing ?? this.trackListing,
      matches: matches ?? this.matches,
      coverArt: coverArt == _sentinel
          ? this.coverArt
          : coverArt as CoverArtResult?,
      coverArtLoading: coverArtLoading ?? this.coverArtLoading,
      error: error == _sentinel ? this.error : error as String?,
      fingerprintProgress: fingerprintProgress == _sentinel
          ? this.fingerprintProgress
          : fingerprintProgress as FingerprintProgress?,
      queueLength: queueLength ?? this.queueLength,
      isPartialMatch: isPartialMatch ?? this.isPartialMatch,
      optedOutPaths: optedOutPaths ?? this.optedOutPaths,
      allSelectedFiles: allSelectedFiles ?? this.allSelectedFiles,
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
  const FingerprintProgress({required this.completed, required this.total});

  /// Number of files processed so far.
  final int completed;

  /// Total number of files to process.
  final int total;
}
