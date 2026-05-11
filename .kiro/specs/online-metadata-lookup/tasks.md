# Implementation Plan: Online Metadata Lookup

## Overview

This plan implements online metadata lookup capabilities, building incrementally from core service infrastructure (rate limiter, cache, models) through individual API services, then the matching/apply logic, state management, and finally the UI layer. Each step builds on the previous, ensuring no orphaned code.

## Tasks

- [x] 1. Create shared models and core infrastructure
  - [x] 1.1 Create unified search result and track info models
    - Create `lib/features/online_lookup/data/models/search_result.dart`
    - Define `SearchResult` class with `id`, `title`, `artist`, `year`, `country`, `trackCount`, `source`
    - Define `SearchSource` enum with `musicBrainz`, `discogs`
    - Define `TrackInfo` class with `title`, `position`, `discNumber`, `durationMs`, `artist`
    - _Requirements: 1.4, 2.3, 4.2_

  - [x] 1.2 Create Discogs and AcoustID data models
    - Create `lib/features/online_lookup/data/models/discogs_models.dart`
    - Define `DiscogsRelease` class with `id`, `title`, `artist`, `year`, `country`, `trackCount`
    - Define `DiscogsTrack` class with `title`, `position`, `duration`, `artist`
    - Create `lib/features/online_lookup/data/models/acoustid_models.dart`
    - Define `AcoustIDResult` class with `recordingId`, `confidence`, `title`, `artist`
    - Define `FingerprintResult` class with `filePath`, `fingerprint`, `durationSeconds`
    - _Requirements: 3.2, 3.3, 3.4_

  - [x] 1.3 Create cover art and matching models
    - Create `lib/features/online_lookup/data/models/cover_art_result.dart`
    - Define `CoverArtResult` class with `imageBytes`, `mimeType`
    - Create `lib/features/online_lookup/data/models/track_file_match.dart`
    - Define `TrackFileMatch` class with `track`, `file`, `confidence`
    - Define `MatchConfidence` enum with `exact`, `duration`, `unmatched`
    - _Requirements: 5.1, 5.2, 6.1_

  - [x] 1.4 Create apply result models
    - Create `lib/features/online_lookup/data/models/apply_result.dart`
    - Define `ApplyResult` class with `successCount`, `failureCount`, `fileResults`
    - Define `ApplyFileResult` class with `path`, `success`, `error`
    - _Requirements: 7.5, 7.6_

  - [x] 1.5 Implement RateLimiter
    - Create `lib/features/online_lookup/data/rate_limiter.dart`
    - Implement request queuing with configurable `maxRequests` per `perDuration`
    - Implement automatic retry on HTTP 429 using Retry-After header
    - Expose `queueLength` and `queueLengthStream` for UI binding
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [ ]* 1.6 Write property tests for RateLimiter
    - **Property 12: Rate limiter enforces configured intervals**
    - **Property 13: Rate limiter respects Retry-After on 429**
    - **Validates: Requirements 8.1, 8.2, 8.4**

  - [x] 1.7 Implement LookupCache
    - Create `lib/features/online_lookup/data/lookup_cache.dart`
    - Implement `cacheSearchResults` / `getSearchResults` keyed by normalized query string
    - Implement `cacheTrackListing` / `getTrackListing` keyed by release ID
    - Implement `clear()` method
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [ ]* 1.8 Write property tests for LookupCache
    - **Property 14: Cache round-trip**
    - **Property 15: Cache hit avoids redundant API calls**
    - **Validates: Requirements 9.1, 9.2, 9.3**

- [x] 2. Implement API services
  - [x] 2.1 Extend MusicBrainzService with rate limiting and unified models
    - Update `lib/features/online_lookup/data/musicbrainz_service.dart`
    - Accept `RateLimiter` in constructor instead of raw `http.Client`
    - Add method to convert `MusicBrainzRelease` to `SearchResult`
    - Add method to convert track listing to `List<TrackInfo>`
    - Add method to fetch recording metadata by recording ID (for AcoustID flow)
    - _Requirements: 1.3, 3.3, 4.1_

  - [x] 2.2 Implement DiscogsService
    - Create `lib/features/online_lookup/data/discogs_service.dart`
    - Implement `searchReleases` with artist, album, year, pagination parameters
    - Include personal access token in request headers
    - Implement `getReleaseTracks` to fetch full track listing for a release
    - Convert results to unified `SearchResult` and `TrackInfo` models
    - Use `RateLimiter` for all requests
    - _Requirements: 2.1, 2.2, 2.4, 4.1_

  - [x] 2.3 Implement AcoustIDService
    - Create `lib/features/online_lookup/data/acoustid_service.dart`
    - Implement `lookup` method that submits fingerprint and duration to AcoustID API
    - Parse response and return `List<AcoustIDResult>` sorted by confidence descending
    - Use `RateLimiter` for requests
    - _Requirements: 3.2, 3.3_

  - [x] 2.4 Implement FingerprintGenerator
    - Create `lib/features/online_lookup/data/fingerprint_generator.dart`
    - Implement `generate(String filePath)` using `Process.run` to invoke `fpcalc`
    - Parse stdout for fingerprint and duration values
    - Implement 10-second timeout with process kill on timeout
    - Implement `generateBatch` with sequential processing and progress callback
    - Throw `FingerprintException` on binary not found, timeout, or non-zero exit
    - _Requirements: 3.1, 3.5, 3.7, 12.1, 12.2, 12.3_

  - [x] 2.5 Implement CoverArtService
    - Create `lib/features/online_lookup/data/cover_art_service.dart`
    - Implement `getFrontCover(String mbReleaseId)` fetching from Cover Art Archive
    - Return `CoverArtResult` with image bytes and MIME type, or null if not available
    - Handle 404 gracefully (return null)
    - Use `RateLimiter` for requests
    - _Requirements: 6.1, 6.2, 6.3, 6.5_

- [x] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement matching and apply logic
  - [x] 4.1 Implement TrackMatcher
    - Create `lib/features/online_lookup/data/track_matcher.dart`
    - Implement `autoMatch` with order-based strategy when file count equals track count
    - Implement duration-based fallback strategy with ±3 second tolerance
    - Mark unmatched entries with `MatchConfidence.unmatched`
    - _Requirements: 5.1, 5.2, 5.3, 5.5_

  - [ ]* 4.2 Write property tests for TrackMatcher
    - **Property 6: Order-based matching when counts are equal**
    - **Property 7: Duration-based matching respects tolerance**
    - **Property 8: Unmatched entries on count mismatch**
    - **Validates: Requirements 5.1, 5.2, 5.5**

  - [x] 4.3 Implement MetadataApplicator
    - Create `lib/features/online_lookup/data/metadata_applicator.dart`
    - Implement `apply` method that writes selected fields to matched files via TagWriterService
    - Register a single `BatchTagEditCommand` with UndoRedoManager for all successful writes
    - Handle partial failures: continue processing remaining files, report per-file results
    - Only write fields that are in the `selectedFields` set
    - _Requirements: 7.1, 7.3, 7.4, 7.5, 7.6_

  - [ ]* 4.4 Write property tests for MetadataApplicator field filtering and apply summary
    - **Property 9: Preview generation shows correct field values**
    - **Property 10: Only selected fields are written**
    - **Property 11: Apply summary accuracy**
    - **Validates: Requirements 7.2, 7.3, 7.6**

  - [x] 4.5 Implement pre-fill extraction and query construction helpers
    - Create `lib/features/online_lookup/data/lookup_helpers.dart`
    - Implement `extractPreFillData(List<AudioFile> files)` returning artist/album from first file
    - Implement `buildMusicBrainzQuery` that constructs Lucene query from artist, album, year
    - Implement `mergeResults` that combines results from multiple sources preserving source indicators
    - Implement `groupTracksByDisc` that groups TrackInfo list by disc number
    - _Requirements: 1.1, 1.2, 1.3, 2.3, 4.3_

  - [ ]* 4.6 Write property tests for lookup helpers
    - **Property 1: Pre-fill extraction returns first file's tags**
    - **Property 2: Search query construction includes all provided parameters**
    - **Property 3: Multi-source merge preserves all results with source indicators**
    - **Property 5: Track grouping by disc number**
    - **Validates: Requirements 1.1, 1.2, 1.3, 2.3, 4.3**

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement state management
  - [x] 6.1 Implement LookupSettings model and LookupSettingsNotifier
    - Create `lib/features/online_lookup/data/models/lookup_settings.dart`
    - Define `LookupSettings` class with `discogsToken`, `acoustIdApiKey`, `fpcalcPath`, `defaultSource`, `autoFetchCoverArt`
    - Create `lib/features/online_lookup/data/providers/lookup_settings_provider.dart`
    - Implement load/save from `shared_preferences`
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [ ]* 6.2 Write property test for settings persistence
    - **Property 16: Settings persistence round-trip**
    - **Validates: Requirements 10.6**

  - [x] 6.3 Implement LookupState model and LookupStateNotifier
    - Create `lib/features/online_lookup/data/models/lookup_state.dart`
    - Define `LookupState` class with status, searchResults, selectedResult, trackListing, matches, coverArt, error, fingerprintProgress, queueLength
    - Define `LookupStatus` enum and `FingerprintProgress` class
    - Create `lib/features/online_lookup/data/providers/lookup_state_provider.dart`
    - Implement `LookupStateNotifier` with methods: `search`, `selectResult`, `identifyFiles`, `updateMatching`, `applyMetadata`, `cancel`
    - Wire to MusicBrainzService, DiscogsService, AcoustIDService, FingerprintGenerator, CoverArtService, TrackMatcher, MetadataApplicator, LookupCache
    - Implement cancellation support for all async operations
    - _Requirements: 1.3, 1.6, 1.7, 2.2, 3.1, 3.6, 4.1, 4.4, 5.1, 6.1, 7.3, 7.4, 11.1, 11.2, 11.3_

  - [x] 6.4 Create Riverpod service providers for lookup feature
    - Create `lib/features/online_lookup/data/providers/service_providers.dart`
    - Define providers for: RateLimiter (per-service instances), LookupCache, MusicBrainzService, DiscogsService, AcoustIDService, FingerprintGenerator, CoverArtService, TrackMatcher, MetadataApplicator
    - Wire dependencies (TagWriterService, UndoRedoManager from existing providers)
    - _Requirements: 8.1, 8.2, 10.7_

- [x] 7. Implement UI layer
  - [x] 7.1 Implement LookupDialog search panel
    - Create `lib/features/online_lookup/presentation/widgets/lookup_dialog.dart`
    - Implement modal dialog with search form (artist, album, year fields)
    - Pre-fill artist and album from selected files
    - Add source selector (MusicBrainz, Discogs, Both) with Discogs disabled when token not configured
    - Add "Identify by Fingerprint" button
    - Display loading indicator during search
    - Display "no results" message when search returns empty
    - Display error messages with retry button on network failure
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 2.1, 2.4, 2.5, 11.1_

  - [x] 7.2 Implement search results list and release detail view
    - Add results list showing artist, album title, year, country, track count, source indicator
    - Implement pagination or "load more" for results exceeding 25
    - On result selection, fetch and display track listing grouped by disc number
    - Show disc headers for multi-disc releases
    - Display rate limit queue status indicator
    - _Requirements: 1.4, 1.5, 2.3, 4.1, 4.2, 4.3, 4.4, 8.3_

  - [x] 7.3 Implement track matching and cover art panel
    - Display proposed track-to-file mapping after auto-match
    - Allow manual reordering via drag-and-drop
    - Visually indicate unmatched files or tracks
    - Display cover art thumbnail when available, placeholder when not
    - Add checkbox to include/exclude cover art from apply
    - Show fingerprint progress indicator during identification
    - _Requirements: 5.3, 5.4, 5.5, 6.2, 6.3, 6.4, 3.4, 3.7_

  - [x] 7.4 Implement metadata preview and apply panel
    - Add field selection checkboxes (Title, Artist, Album, Year, Genre, Track Number, Disc Number, Album Artist, Cover Art)
    - Display preview table showing current vs. new values for each selected field per file
    - Add confirm button to trigger apply
    - Display apply summary (success/failure counts) on completion
    - Close dialog or allow further actions after apply
    - _Requirements: 7.1, 7.2, 7.3, 7.5, 7.6_

  - [x] 7.5 Add lookup settings to Settings page
    - Update `lib/features/settings/presentation/pages/settings_page.dart`
    - Add "Online Lookup" section with:
      - Discogs personal access token text input
      - AcoustID API key text input
      - fpcalc binary path file selector
      - Default search source dropdown
      - Auto-fetch cover art toggle
    - Wire to LookupSettingsNotifier for persistence
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [x] 7.6 Wire LookupDialog launch from toolbar
    - Add "Online Lookup" button/menu item to the toolbar or tag editor panel
    - Pass currently selected files to the LookupDialog on open
    - Handle dialog close with cancellation of pending operations
    - _Requirements: 11.3_

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The existing `MusicBrainzService` will be extended (not replaced) to add rate limiting and unified model conversion
- All HTTP services use the shared `RateLimiter` — no direct `http.Client` usage in services
- `shared_preferences` is already a project dependency
- The `http` package is already a project dependency
- Cover Art Archive uses MusicBrainz release IDs, so cover art is only available for MusicBrainz results
