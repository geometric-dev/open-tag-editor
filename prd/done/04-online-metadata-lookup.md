# PRD 04: Online Metadata Lookup

## Problem Statement

Audio files often have incomplete or missing metadata. Users need to search online music databases to find correct tag information (artist, album, track listing, year, genre, cover art) and apply it to their files. The original Tag&Rename relied on Amazon, Tracktype, and Discogs — some of these integrations broke over time. We need a modern, reliable set of sources.

## Goals

- Let users search online databases by artist/album/year and retrieve full album metadata.
- Support audio fingerprinting for identifying unknown tracks.
- Apply retrieved metadata (including cover art) to selected files.
- Use services with stable, well-maintained APIs.

## Available Services (Researched May 2025)

| Service | Status | Use Case | Auth Required |
|---------|--------|----------|---------------|
| **MusicBrainz** | Active, free, open | Primary metadata source. 25M+ recordings. RESTful JSON/XML API, no auth required (rate-limited to 1 req/sec with User-Agent). | No (User-Agent header) |
| **AcoustID + Chromaprint** | Active, free, open | Audio fingerprint identification. Submits a fingerprint, returns MusicBrainz recording IDs. Requires free API key. | API key (free) |
| **Discogs** | Active, free tier | Secondary metadata source. Strong for vinyl/physical releases. REST API, requires OAuth or personal token for search. | Personal token or OAuth |
| **Cover Art Archive** | Active, free, open | Album artwork linked to MusicBrainz releases. No auth. | No |

### Deprecated / Not Recommended
- **Amazon Product API** — Requires affiliate account, heavily restricted, not designed for metadata lookup.
- **Tracktype** — Service appears defunct.

## Functional Requirements

### Search Interface
- A dialog/panel where users enter search criteria:
  - Artist (pre-filled from selected file's existing tag if available)
  - Album (pre-filled)
  - Year (optional filter)
- Search button queries the selected source(s).
- Results displayed in a list: Artist | Album | Year | Label | Track Count | Source.
- Pagination / "Load more" for large result sets.

### Source Selection
- User can choose which source(s) to search:
  - MusicBrainz (default, always available)
  - Discogs (requires one-time token setup in Settings)
- Multiple sources can be queried in parallel; results are merged and deduplicated.

### Album Detail & Track Matching
- Selecting a result loads the full track listing from that release.
- Display: Track # | Title | Duration | Artist (if varies).
- Auto-match loaded tracks to selected files by:
  1. Track number order (if files are already in order).
  2. Duration similarity (fuzzy match within ±3 seconds).
  3. Manual drag-and-drop reordering if auto-match is wrong.

### Audio Fingerprinting (AcoustID)
- "Identify" button on selected files:
  1. Generate Chromaprint fingerprint locally.
  2. Submit to AcoustID API.
  3. Retrieve MusicBrainz recording ID.
  4. Fetch full metadata from MusicBrainz.
- Useful for files with no existing tags at all.
- Requires `fpcalc` (Chromaprint CLI) to be available — app should bundle it or guide installation.

### Cover Art
- When a MusicBrainz release is selected, automatically fetch artwork from Cover Art Archive.
- Display artwork preview in the lookup dialog.
- Option to embed cover art into files when applying metadata.

### Apply Metadata
- "Apply" button writes the retrieved metadata to selected files.
- User can choose which fields to apply (checkboxes: Artist, Album, Title, Year, Genre, Track #, Disc #, Album Artist, Cover Art).
- Preview before writing: show current value → new value for each file/field.
- Operation is undoable.

### Rate Limiting & Error Handling
- Respect MusicBrainz rate limit (1 request/second). Queue requests and show progress.
- Respect Discogs rate limit (60 requests/minute for authenticated users).
- Graceful handling of network errors, timeouts, and empty results.
- Cache recent lookups to avoid redundant API calls within a session.

## Settings (PRD cross-reference: Settings page)

- Discogs personal access token input.
- AcoustID API key input.
- Default source preference.
- Whether to auto-fetch cover art.
- Path to `fpcalc` binary (if not bundled).

## Non-Functional Requirements

- Search results should appear within 3 seconds for a typical query.
- Fingerprint generation for a single file should complete within 5 seconds.
- The lookup UI should not block the main file list — user can continue browsing while a search is in progress.

## Out of Scope

- Submitting new fingerprints/metadata back to MusicBrainz or AcoustID.
- Spotify/Apple Music integration (these APIs don't allow metadata extraction for tagging purposes per their ToS).
- Lyrics lookup (potential future feature).

## Dependencies

- **PRD 00 (TagLib FFI Integration)** — Writing fetched metadata and cover art to files requires the safe TagLib writer.
- **PRD 01 (Folder Loading)** — Files must be loaded before lookup can be triggered on a selection.

## Open Questions

- Should we bundle `fpcalc` for each platform, or require the user to install Chromaprint separately? Bundling is better UX but adds binary distribution complexity.
- Should Discogs OAuth flow be in-app, or just accept a personal token pasted from their developer settings? Token is simpler to implement.
