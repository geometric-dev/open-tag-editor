import 'package:flutter_riverpod/legacy.dart';

import '../../../../shared/models/audio_file.dart';
import '../acoustid_service.dart';
import '../cover_art_service.dart';
import '../discogs_service.dart';
import '../fingerprint_generator.dart';
import '../lookup_cache.dart';
import '../lookup_helpers.dart';
import '../metadata_applicator.dart';
import '../models/apply_result.dart';
import '../models/lookup_state.dart';
import '../models/search_result.dart';
import '../models/track_file_match.dart';
import '../musicbrainz_service.dart';
import '../partial_match_applicator.dart';
import '../track_matcher.dart';

/// Provider for the lookup workflow state.
final lookupStateProvider =
    StateNotifierProvider<LookupStateNotifier, LookupState>((ref) {
  return LookupStateNotifier();
});

/// Manages the full lookup workflow state.
///
/// Orchestrates search, track listing, fingerprinting, matching,
/// cover art, and metadata application.
class LookupStateNotifier extends StateNotifier<LookupState> {
  LookupStateNotifier() : super(const LookupState());

  late MusicBrainzService _musicBrainzService;
  DiscogsService? _discogsService;
  late AcoustIDService _acoustIdService;
  FingerprintGenerator? _fingerprintGenerator;
  late CoverArtService _coverArtService;
  late MetadataApplicator _metadataApplicator;
  PartialMatchApplicator? _partialMatchApplicator;
  late LookupCache _cache;
  bool _configured = false;
  bool _cancelled = false;

  /// Injects service dependencies. Must be called before any workflow method.
  void configure({
    required MusicBrainzService musicBrainzService,
    DiscogsService? discogsService,
    required AcoustIDService acoustIdService,
    FingerprintGenerator? fingerprintGenerator,
    required CoverArtService coverArtService,
    required MetadataApplicator metadataApplicator,
    PartialMatchApplicator? partialMatchApplicator,
    required LookupCache cache,
  }) {
    _musicBrainzService = musicBrainzService;
    _discogsService = discogsService;
    _acoustIdService = acoustIdService;
    _fingerprintGenerator = fingerprintGenerator;
    _coverArtService = coverArtService;
    _metadataApplicator = metadataApplicator;
    _partialMatchApplicator = partialMatchApplicator;
    _cache = cache;
    _configured = true;
  }

  /// Asserts that [configure] has been called.
  void _assertConfigured() {
    assert(_configured, 'LookupStateNotifier.configure() must be called first');
  }

  /// Performs a search across selected sources.
  Future<void> search({
    required String? artist,
    required String? album,
    String? year,
    required Set<SearchSource> sources,
  }) async {
    _assertConfigured();
    _cancelled = false;
    state = state.copyWith(status: LookupStatus.searching, error: null);

    // Check cache first
    final cacheKey = LookupHelpers.buildCacheKey(
      artist: artist,
      album: album,
      year: year,
      sources: sources,
    );
    final cached = _cache.getSearchResults(cacheKey);
    if (cached != null) {
      state = state.copyWith(
        status: LookupStatus.idle,
        searchResults: cached,
      );
      return;
    }

    try {
      final mbResults = sources.contains(SearchSource.musicBrainz)
          ? await _musicBrainzService.searchReleases(
              artist: artist,
              album: album,
              year: year,
            )
          : <SearchResult>[];

      if (_cancelled) return;

      final discogsResults = sources.contains(SearchSource.discogs) &&
              _discogsService != null
          ? await _discogsService!.searchReleases(
              artist: artist,
              album: album,
              year: year != null ? int.tryParse(year) : null,
            )
          : <SearchResult>[];

      if (_cancelled) return;

      final merged = LookupHelpers.mergeResults(mbResults, discogsResults);
      _cache.cacheSearchResults(cacheKey, merged);

      state = state.copyWith(
        status: LookupStatus.idle,
        searchResults: merged,
      );
    } catch (e) {
      state = state.copyWith(
        status: LookupStatus.error,
        error: 'Search failed: $e',
      );
    }
  }

  /// Selects a result and fetches its track listing.
  Future<void> selectResult(SearchResult result) async {
    _assertConfigured();
    _cancelled = false;
    state = state.copyWith(
      status: LookupStatus.loadingTracks,
      selectedResult: result,
      coverArtLoading: true,
    );

    // Check cache
    final cachedTracks = _cache.getTrackListing(result.id);
    if (cachedTracks != null) {
      state = state.copyWith(
        status: LookupStatus.idle,
        trackListing: cachedTracks,
      );
    } else {
      try {
        List<TrackInfo> tracks;
        if (result.source == SearchSource.musicBrainz) {
          tracks = await _musicBrainzService.getReleaseTracks(result.id);
        } else {
          tracks = await _discogsService!.getReleaseTracks(int.parse(result.id));
        }

        if (_cancelled) return;

        _cache.cacheTrackListing(result.id, tracks);
        state = state.copyWith(
          status: LookupStatus.idle,
          trackListing: tracks,
        );
      } catch (e) {
        state = state.copyWith(
          status: LookupStatus.error,
          error: 'Failed to load tracks: $e',
        );
      }
    }

    // Fetch cover art in parallel (MusicBrainz only)
    if (result.source == SearchSource.musicBrainz) {
      try {
        final art = await _coverArtService.getFrontCover(result.id);
        if (!_cancelled) {
          state = state.copyWith(coverArt: art, coverArtLoading: false);
        }
      } catch (_) {
        state = state.copyWith(coverArtLoading: false);
      }
    } else {
      state = state.copyWith(coverArtLoading: false);
    }
  }

  /// Auto-matches tracks to the given files.
  void matchFiles(List<AudioFile> files) {
    final matches = TrackMatcher.autoMatch(
      tracks: state.trackListing,
      files: files,
    );
    state = state.copyWith(matches: matches);
  }

  /// Triggers multi-signal matching for partial match scenario.
  ///
  /// Sets [isPartialMatch] to true and stores all selected files for
  /// display in the apply panel.
  void matchFilesPartial(List<AudioFile> files) {
    final matches = TrackMatcher.autoMatch(
      tracks: state.trackListing,
      files: files,
    );
    state = state.copyWith(
      matches: matches,
      isPartialMatch: true,
      allSelectedFiles: files,
      optedOutPaths: {},
    );
  }

  /// Toggles a file's opt-out status for metadata application.
  void toggleFileOptOut(String path) {
    final current = Set<String>.from(state.optedOutPaths);
    if (current.contains(path)) {
      current.remove(path);
    } else {
      current.add(path);
    }
    state = state.copyWith(optedOutPaths: current);
  }

  /// Manually reassigns a track to a file.
  ///
  /// Removes any existing assignment for [filePath], then assigns [track]
  /// to that file. If [track] is null, the file becomes unassigned.
  void reassignTrack(String filePath, TrackInfo? track) {
    final updatedMatches = List<TrackFileMatch>.from(state.matches);

    // Remove existing assignment for this file.
    final existingIdx =
        updatedMatches.indexWhere((m) => m.file?.path == filePath);
    if (existingIdx >= 0) {
      final existing = updatedMatches[existingIdx];
      updatedMatches[existingIdx] = TrackFileMatch(
        track: existing.track,
        file: null,
        confidence: MatchConfidence.unmatched,
      );
    }

    // Assign the new track to this file.
    if (track != null) {
      final targetIdx = updatedMatches.indexWhere((m) => m.track == track);
      if (targetIdx >= 0) {
        final targetFile =
            state.allSelectedFiles.firstWhere((f) => f.path == filePath);
        updatedMatches[targetIdx] = TrackFileMatch(
          track: track,
          file: targetFile,
          confidence: MatchConfidence.high,
          score: 1.0,
        );
      }
    }

    state = state.copyWith(matches: updatedMatches);
  }

  /// Clears a track assignment from a file.
  void clearTrackAssignment(String filePath) {
    reassignTrack(filePath, null);
  }

  /// Applies metadata using the partial match applicator.
  ///
  /// Album-level metadata is written to all non-opted-out files.
  /// Track-level metadata is written only to files with a track assignment.
  Future<ApplyResult> applyPartialMetadata({
    required Set<String> selectedFields,
    required bool applyCoverArt,
  }) async {
    _assertConfigured();
    state = state.copyWith(status: LookupStatus.applying);

    try {
      final result = await _partialMatchApplicator!.apply(
        matches: state.matches,
        allFiles: state.allSelectedFiles,
        selectedFields: selectedFields,
        optedOutPaths: state.optedOutPaths,
        totalFileCount: state.allSelectedFiles.length,
        coverArt: applyCoverArt ? state.coverArt : null,
        applyCoverArt: applyCoverArt,
        albumTitle: state.selectedResult?.title,
        albumArtist: state.selectedResult?.artist,
        year: state.selectedResult?.year,
      );
      state = state.copyWith(status: LookupStatus.complete);
      return result;
    } catch (e) {
      state = state.copyWith(
        status: LookupStatus.error,
        error: 'Apply failed: $e',
      );
      return ApplyResult(
        successCount: 0,
        failureCount: state.allSelectedFiles.length,
        fileResults: [],
      );
    }
  }

  /// Updates the track-to-file matching (e.g., after manual reorder).
  void updateMatching(List<TrackFileMatch> matches) {
    state = state.copyWith(matches: matches);
  }

  /// Triggers fingerprint identification for selected files.
  Future<void> identifyFiles(List<AudioFile> files) async {
    _assertConfigured();
    if (_fingerprintGenerator == null) {
      state = state.copyWith(
        status: LookupStatus.error,
        error: 'Fingerprinting not configured. Check fpcalc path in Settings.',
      );
      return;
    }

    _cancelled = false;
    state = state.copyWith(
      status: LookupStatus.fingerprinting,
      fingerprintProgress: FingerprintProgress(completed: 0, total: files.length),
    );

    final filePaths = files.map((f) => f.path).toList();
    final fingerprints = await _fingerprintGenerator!.generateBatch(
      filePaths,
      onProgress: (completed, total) {
        if (!_cancelled) {
          state = state.copyWith(
            fingerprintProgress: FingerprintProgress(
              completed: completed,
              total: total,
            ),
          );
        }
      },
    );

    if (_cancelled) return;

    // Look up each fingerprint
    final results = <SearchResult>[];
    for (final fp in fingerprints) {
      final matches = await _acoustIdService.lookup(
        fingerprint: fp.fingerprint,
        durationSeconds: fp.durationSeconds,
      );
      if (matches.isNotEmpty) {
        final best = matches.first;
        results.add(SearchResult(
          id: best.recordingId,
          title: best.title ?? 'Unknown',
          artist: best.artist,
          source: SearchSource.musicBrainz,
        ),);
      }
    }

    state = state.copyWith(
      status: LookupStatus.idle,
      searchResults: results,
      fingerprintProgress: null,
    );
  }

  /// Applies metadata to matched files.
  Future<ApplyResult> applyMetadata({
    required Set<String> selectedFields,
    required bool applyCoverArt,
  }) async {
    _assertConfigured();
    state = state.copyWith(status: LookupStatus.applying);

    try {
      final result = await _metadataApplicator.apply(
        matches: state.matches,
        selectedFields: selectedFields,
        coverArt: applyCoverArt ? state.coverArt : null,
        applyCoverArt: applyCoverArt,
        albumTitle: state.selectedResult?.title,
        albumArtist: state.selectedResult?.artist,
        year: state.selectedResult?.year,
      );

      state = state.copyWith(status: LookupStatus.complete);
      return result;
    } catch (e) {
      state = state.copyWith(
        status: LookupStatus.error,
        error: 'Apply failed: $e',
      );
      return ApplyResult(
        successCount: 0,
        failureCount: state.matches.length,
        fileResults: [],
      );
    }
  }

  /// Cancels any in-progress operation.
  void cancel() {
    _cancelled = true;
    state = state.copyWith(status: LookupStatus.idle);
  }

  /// Clears the selected result detail and returns to the results list.
  ///
  /// Preserves [searchResults] so the user can pick an alternative
  /// without re-searching.
  void deselectResult() {
    _cancelled = true;
    state = LookupState(
      status: LookupStatus.idle,
      searchResults: state.searchResults,
    );
  }

  /// Resets the state to idle.
  void reset() {
    _cancelled = false;
    state = const LookupState();
  }
}
