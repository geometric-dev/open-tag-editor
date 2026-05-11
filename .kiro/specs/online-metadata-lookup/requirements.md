# Requirements Document

## Introduction

This feature enables users to search online music databases (MusicBrainz, Discogs, AcoustID/Chromaprint, Cover Art Archive) and apply retrieved metadata to audio files. It covers text-based search by artist/album/year, audio fingerprint identification for untagged files, album track matching, cover art retrieval, and a controlled apply workflow with undo support. The feature integrates with the existing tag writing infrastructure and undo/redo system.

## Glossary

- **Lookup_Dialog**: The modal dialog where users enter search criteria, view results, match tracks, and apply metadata.
- **MusicBrainz_Service**: The service that communicates with the MusicBrainz JSON Web Service v2 for release and recording searches.
- **Discogs_Service**: The service that communicates with the Discogs REST API for release searches using a personal access token.
- **AcoustID_Service**: The service that submits audio fingerprints to the AcoustID API and retrieves MusicBrainz recording IDs.
- **Fingerprint_Generator**: The component that invokes the `fpcalc` (Chromaprint CLI) binary to generate audio fingerprints from audio files.
- **Cover_Art_Service**: The service that fetches album artwork from the Cover Art Archive using MusicBrainz release IDs.
- **Rate_Limiter**: The component that queues outgoing HTTP requests to respect per-service rate limits.
- **Track_Matcher**: The component that automatically maps retrieved album tracks to selected audio files.
- **Metadata_Applicator**: The component that writes retrieved metadata fields to audio files via the existing TagWriterService.
- **Lookup_Cache**: An in-memory cache that stores recent search results and release details within a session.
- **Audio_File**: The data model representing a loaded audio file with its metadata tags, audio properties, and file info.
- **Selection_State**: The set of currently selected file paths managed via Riverpod state provider.

## Requirements

### Requirement 1: Metadata Search Dialog

**User Story:** As a user, I want to search online databases by artist, album, and year, so that I can find the correct metadata for my audio files.

#### Acceptance Criteria

1. WHEN the user opens the Lookup_Dialog with files selected, THE Lookup_Dialog SHALL pre-fill the artist field from the first selected Audio_File's existing artist tag.
2. WHEN the user opens the Lookup_Dialog with files selected, THE Lookup_Dialog SHALL pre-fill the album field from the first selected Audio_File's existing album tag.
3. WHEN the user submits a search query, THE MusicBrainz_Service SHALL query the MusicBrainz API with the provided artist, album, and year parameters.
4. WHEN search results are returned, THE Lookup_Dialog SHALL display each result showing artist, album title, year, country, track count, and source name.
5. WHEN more than 25 results are available, THE Lookup_Dialog SHALL provide pagination or a "load more" control to retrieve additional results.
6. IF the search query returns no results, THEN THE Lookup_Dialog SHALL display a message indicating no matches were found.
7. IF a network error occurs during search, THEN THE Lookup_Dialog SHALL display an error message describing the failure and allow the user to retry.

### Requirement 2: Multi-Source Search

**User Story:** As a user, I want to search both MusicBrainz and Discogs simultaneously, so that I can find releases that may only exist in one database.

#### Acceptance Criteria

1. THE Lookup_Dialog SHALL provide a source selector allowing the user to choose MusicBrainz, Discogs, or both.
2. WHEN both sources are selected, THE Lookup_Dialog SHALL query MusicBrainz_Service and Discogs_Service in parallel.
3. WHEN results from multiple sources are returned, THE Lookup_Dialog SHALL merge results into a single list with a source indicator on each entry.
4. WHILE the Discogs personal access token is not configured, THE Lookup_Dialog SHALL disable the Discogs source option and display a hint to configure it in Settings.
5. THE MusicBrainz_Service SHALL be the default selected source when the Lookup_Dialog opens.

### Requirement 3: Audio Fingerprint Identification

**User Story:** As a user, I want to identify unknown audio files by their audio fingerprint, so that I can retrieve metadata for files with no existing tags.

#### Acceptance Criteria

1. WHEN the user triggers the "Identify" action on selected files, THE Fingerprint_Generator SHALL invoke the `fpcalc` binary to generate a Chromaprint fingerprint for each selected Audio_File.
2. WHEN a fingerprint is generated, THE AcoustID_Service SHALL submit the fingerprint and file duration to the AcoustID API.
3. WHEN the AcoustID API returns MusicBrainz recording IDs, THE MusicBrainz_Service SHALL fetch full recording metadata using the highest-confidence recording ID.
4. WHEN identification results are available, THE Lookup_Dialog SHALL display the matched recording metadata (title, artist, album, year) for each file.
5. IF the `fpcalc` binary is not found at the configured path, THEN THE Fingerprint_Generator SHALL display an error message guiding the user to configure the fpcalc path in Settings.
6. IF the AcoustID API returns no matches for a fingerprint, THEN THE Lookup_Dialog SHALL indicate that the file could not be identified.
7. WHEN fingerprinting multiple files, THE Lookup_Dialog SHALL display a progress indicator showing the current file number out of total.

### Requirement 4: Album Detail and Track Listing

**User Story:** As a user, I want to view the full track listing of a selected album result, so that I can verify it matches my files before applying metadata.

#### Acceptance Criteria

1. WHEN the user selects a search result, THE MusicBrainz_Service SHALL fetch the full track listing for that release.
2. WHEN the track listing is loaded, THE Lookup_Dialog SHALL display each track showing disc number, track number, title, duration, and artist (if it differs from the album artist).
3. WHEN the release contains multiple discs, THE Lookup_Dialog SHALL group tracks by disc number with disc headers.
4. IF fetching the track listing fails, THEN THE Lookup_Dialog SHALL display an error message and allow the user to retry.

### Requirement 5: Track-to-File Matching

**User Story:** As a user, I want the app to automatically match album tracks to my selected files, so that I do not have to manually assign each track.

#### Acceptance Criteria

1. WHEN a track listing is loaded and files are selected, THE Track_Matcher SHALL attempt to auto-match tracks to files by track number order.
2. WHEN track number order matching is not possible (file count differs from track count), THE Track_Matcher SHALL attempt matching by duration similarity with a tolerance of plus or minus 3 seconds.
3. WHEN auto-matching is complete, THE Lookup_Dialog SHALL display the proposed mapping showing each file paired with its matched track.
4. WHEN the user disagrees with the auto-match, THE Lookup_Dialog SHALL allow manual reordering of the file-to-track mapping via drag-and-drop.
5. WHEN the number of selected files differs from the number of tracks, THE Lookup_Dialog SHALL indicate unmatched files or tracks visually.

### Requirement 6: Cover Art Retrieval

**User Story:** As a user, I want to see and apply album cover art from online sources, so that my files have embedded artwork.

#### Acceptance Criteria

1. WHEN a MusicBrainz release is selected in the Lookup_Dialog, THE Cover_Art_Service SHALL fetch the front cover image from the Cover Art Archive.
2. WHEN cover art is available, THE Lookup_Dialog SHALL display a preview thumbnail of the artwork.
3. WHEN cover art is not available for a release, THE Lookup_Dialog SHALL display a placeholder indicating no artwork was found.
4. THE Lookup_Dialog SHALL provide a checkbox allowing the user to include or exclude cover art from the apply operation.
5. IF fetching cover art fails due to a network error, THEN THE Lookup_Dialog SHALL display the placeholder and allow the user to retry.

### Requirement 7: Metadata Apply with Preview

**User Story:** As a user, I want to preview what will change before applying metadata, so that I can avoid overwriting data I want to keep.

#### Acceptance Criteria

1. THE Lookup_Dialog SHALL provide checkboxes for each metadata field (Title, Artist, Album, Year, Genre, Track Number, Disc Number, Album Artist, Cover Art) allowing the user to select which fields to apply.
2. WHEN the user initiates the apply action, THE Lookup_Dialog SHALL display a preview showing current value and new value for each selected field on each matched file.
3. WHEN the user confirms the apply, THE Metadata_Applicator SHALL write the selected metadata fields to each matched Audio_File using the TagWriterService.
4. WHEN metadata is applied successfully, THE Metadata_Applicator SHALL register the operation with the UndoRedoManager as a single undoable command.
5. IF writing metadata to a file fails, THEN THE Metadata_Applicator SHALL report the failure for that file and continue processing remaining files.
6. WHEN the apply operation completes, THE Lookup_Dialog SHALL display a summary showing how many files were updated successfully and how many failed.

### Requirement 8: Rate Limiting

**User Story:** As a user, I want the app to respect API rate limits automatically, so that my requests are not rejected and I am not banned from services.

#### Acceptance Criteria

1. THE Rate_Limiter SHALL enforce a maximum of 1 request per second to the MusicBrainz API.
2. THE Rate_Limiter SHALL enforce a maximum of 60 requests per minute to the Discogs API.
3. WHILE requests are queued due to rate limiting, THE Lookup_Dialog SHALL display a progress indicator showing the queue status.
4. WHEN a rate limit response (HTTP 429) is received, THE Rate_Limiter SHALL pause requests to that service for the duration specified in the response headers and then retry.

### Requirement 9: Session Cache

**User Story:** As a user, I want recent search results to be cached within my session, so that navigating back to a previous search does not require another API call.

#### Acceptance Criteria

1. WHEN a search query returns results, THE Lookup_Cache SHALL store the results keyed by the query parameters.
2. WHEN the user submits a query that matches a cached entry, THE Lookup_Dialog SHALL display the cached results immediately without making an API call.
3. WHEN a release track listing is fetched, THE Lookup_Cache SHALL store the track listing keyed by release ID.
4. WHEN the application session ends, THE Lookup_Cache SHALL discard all cached data.

### Requirement 10: Lookup Settings

**User Story:** As a user, I want to configure API credentials and preferences for online lookup, so that I can use all available sources and customize behavior.

#### Acceptance Criteria

1. THE Settings page SHALL provide a text input for the Discogs personal access token.
2. THE Settings page SHALL provide a text input for the AcoustID API key.
3. THE Settings page SHALL provide a file path selector for the `fpcalc` binary location.
4. THE Settings page SHALL provide a dropdown to select the default search source (MusicBrainz, Discogs, or Both).
5. THE Settings page SHALL provide a toggle for auto-fetching cover art when a release is selected.
6. WHEN the user saves settings, THE Settings page SHALL persist all lookup-related preferences across application sessions.
7. WHEN the Discogs token is empty, THE Discogs_Service SHALL not attempt any API calls and the Discogs source option SHALL be disabled in the Lookup_Dialog.

### Requirement 11: Non-Blocking Lookup Operations

**User Story:** As a user, I want to continue browsing my file list while a search or fingerprint operation is running, so that the app remains responsive.

#### Acceptance Criteria

1. WHILE a search operation is in progress, THE Lookup_Dialog SHALL display a loading indicator without blocking the main application window.
2. WHILE fingerprint generation is in progress, THE Lookup_Dialog SHALL display progress without blocking the main file list interaction.
3. WHEN the user closes the Lookup_Dialog during an in-progress operation, THE Lookup_Dialog SHALL cancel pending requests gracefully.

### Requirement 12: Fingerprint Generation Performance

**User Story:** As a user, I want fingerprint generation to complete quickly, so that identifying files does not take an unreasonable amount of time.

#### Acceptance Criteria

1. WHEN generating a fingerprint for a single Audio_File, THE Fingerprint_Generator SHALL complete within 5 seconds on a modern desktop machine.
2. WHEN generating fingerprints for multiple files, THE Fingerprint_Generator SHALL process files sequentially to avoid excessive CPU usage.
3. IF the `fpcalc` process exceeds a 10-second timeout for a single file, THEN THE Fingerprint_Generator SHALL terminate the process and report a timeout error for that file.
