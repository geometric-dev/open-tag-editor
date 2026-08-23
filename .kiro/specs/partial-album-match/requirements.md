# Requirements Document

## Introduction

Partial Album Match enables users to apply metadata from an online album match even when the matched album has fewer tracks than the user's local files. This addresses the common scenario where a user has a special/deluxe edition (e.g. 16 tracks) but only a standard edition (e.g. 11 tracks) is available in the database. The matcher uses filename hints and fuzzy title matching alongside duration to produce intuitive pairings. Album-level metadata applies to all selected files, track-specific metadata applies only to matched tracks, and users can opt individual files out of receiving any changes.

## Glossary

- **Partial_Match_Applicator**: The component responsible for applying metadata from a partial album match to local files, distinguishing between album-level and track-level fields.
- **Track_Matcher**: The component that pairs album tracks to local audio files using a multi-signal scoring system (filename track number, fuzzy title, duration).
- **Match_Score**: A composite numeric score combining filename track number, fuzzy title similarity, and duration proximity signals to rank candidate file-to-track pairings.
- **Lookup_Apply_Panel**: The UI panel that displays all selected files with proposed metadata changes and allows per-file opt-out before applying.
- **Album_Metadata**: Fields that describe the album as a whole — album title, album artist, year, genre, and cover art.
- **Track_Metadata**: Fields specific to an individual track — title, track number, disc number, and track artist.
- **Total_File_Count**: The number of files in the user's current selection, used as the denominator in track number formatting.
- **Matched_Track_Count**: The number of tracks in the online album result that has been selected for partial application.
- **Track_Number_Format**: The formatted track number string in the form "position/total" (e.g. "3/16").
- **Lookup_Dialog**: The existing dialog that handles online metadata search, result selection, track matching, and metadata application.
- **Filename_Track_Number**: A leading numeric prefix extracted from a filename (e.g. "01" from "01_Take_Me_Away.mp3") used as a matching signal.
- **Fuzzy_Title_Match**: A similarity comparison between a filename-derived title (e.g. "Take_Me_Away" → "Take Me Away") and an album track title, producing a normalised similarity score.

## Requirements

### Requirement 1: Multi-Signal Track Matching

**User Story:** As a user, I want the matcher to use filename track numbers and title similarity alongside duration, so that tracks are paired intuitively rather than by duration coincidence alone.

#### Acceptance Criteria

1. WHEN matching tracks to files, THE Track_Matcher SHALL extract a Filename_Track_Number from each file's filename by parsing leading digits before the first non-digit separator character.
2. WHEN matching tracks to files, THE Track_Matcher SHALL compute a Fuzzy_Title_Match score between each file's filename-derived title and each album track title.
3. WHEN matching tracks to files, THE Track_Matcher SHALL compute a duration proximity score based on the absolute difference between the file duration and the track duration.
4. THE Track_Matcher SHALL combine Filename_Track_Number match, Fuzzy_Title_Match score, and duration proximity score into a single Match_Score for each candidate file-to-track pairing.
5. THE Track_Matcher SHALL select the file-to-track assignment that maximises the total Match_Score across all pairings, with each file assigned to at most one track.
6. WHEN a file has no leading digits in its filename, THE Track_Matcher SHALL assign a Filename_Track_Number score of zero for that file and rely on title and duration signals.
7. WHEN multiple files produce the same Filename_Track_Number, THE Track_Matcher SHALL use Fuzzy_Title_Match and duration scores to disambiguate.
8. WHEN a Filename_Track_Number conflicts with the best duration match for a given track, THE Track_Matcher SHALL prefer the candidate with the higher composite Match_Score.

### Requirement 2: Fuzzy Title Matching Robustness

**User Story:** As a user, I want fuzzy title matching to handle common filename conventions without producing false positives on generic titles, so that matching is reliable across diverse music libraries.

#### Acceptance Criteria

1. THE Track_Matcher SHALL normalise filenames by replacing underscores, hyphens, and dots with spaces, stripping the file extension, and removing leading track number prefixes before computing Fuzzy_Title_Match.
2. THE Track_Matcher SHALL perform case-insensitive comparison when computing Fuzzy_Title_Match scores.
3. WHEN an album track title is three characters or fewer (e.g. "Intro"), THE Track_Matcher SHALL reduce the Fuzzy_Title_Match weight to avoid false positives on generic titles.
4. WHEN the highest Fuzzy_Title_Match score for a candidate pairing is below a minimum similarity threshold, THE Track_Matcher SHALL treat the title signal as absent and rely on Filename_Track_Number and duration signals only.

### Requirement 3: Album Metadata Application to All Selected Files

**User Story:** As a user, I want album-level metadata applied to all my selected files regardless of track matching, so that every file in the album folder shares consistent album information.

#### Acceptance Criteria

1. WHEN the user applies a partial match, THE Partial_Match_Applicator SHALL write Album_Metadata to all selected local files that have not been opted out.
2. THE Partial_Match_Applicator SHALL treat album title, album artist, year, and cover art as Album_Metadata fields.
3. WHEN cover art is selected for application, THE Partial_Match_Applicator SHALL write the cover art to all non-opted-out selected local files regardless of track matching status.
4. WHEN a file exceeds the matched album's track count and has no track assignment, THE Partial_Match_Applicator SHALL still write Album_Metadata to that file (unless opted out).

### Requirement 4: Track Metadata Application to Matched Files Only

**User Story:** As a user, I want track-specific metadata applied only to files that have a track assignment, so that unmatched bonus tracks are not overwritten with incorrect data.

#### Acceptance Criteria

1. WHEN the user applies a partial match, THE Partial_Match_Applicator SHALL write Track_Metadata only to files that have a corresponding track assignment.
2. THE Partial_Match_Applicator SHALL treat title, track artist, and disc number as Track_Metadata fields.
3. WHEN a local file has no track assignment, THE Partial_Match_Applicator SHALL leave Track_Metadata fields unchanged on that file.

### Requirement 5: Per-File Opt-Out in Apply Panel

**User Story:** As a user, I want to opt individual files out of receiving any metadata changes, so that I can protect specific files from being modified.

#### Acceptance Criteria

1. THE Lookup_Apply_Panel SHALL display a checkbox or toggle for each file (both matched and unmatched) allowing the user to opt that file out of metadata application.
2. WHEN a file is opted out, THE Partial_Match_Applicator SHALL skip that file entirely — writing neither Album_Metadata nor Track_Metadata to it.
3. THE Lookup_Apply_Panel SHALL default all files to opted-in (checkbox checked) when the panel is first displayed.
4. THE Lookup_Apply_Panel SHALL update the summary count to reflect only non-opted-out files (e.g. "Applying to 14 of 16 files").

### Requirement 6: Apply Panel Shows All Selected Files

**User Story:** As a user, I want to see all my selected files in the apply panel — not just matched ones — so that I can review and control what happens to every file.

#### Acceptance Criteria

1. THE Lookup_Apply_Panel SHALL display all selected local files, including those that exceed the matched album's track count.
2. THE Lookup_Apply_Panel SHALL show matched files with a preview of both Album_Metadata and Track_Metadata changes.
3. THE Lookup_Apply_Panel SHALL show unmatched files with a preview of Album_Metadata changes only.

### Requirement 7: Visual Distinction for Unmatched Files

**User Story:** As a user, I want unmatched files to be visually distinct in the apply panel, so that I can immediately see which files will only receive album-level metadata.

#### Acceptance Criteria

1. THE Lookup_Apply_Panel SHALL display a badge or label reading "Album info only" on each unmatched file row.
2. THE Lookup_Apply_Panel SHALL visually differentiate unmatched file rows from matched file rows using a distinct background colour or reduced opacity.
3. THE Lookup_Apply_Panel SHALL group matched files before unmatched files in the list order.

### Requirement 8: Track Count Awareness Summary

**User Story:** As a user, I want the UI to clearly communicate how many files matched versus how many are unmatched, so that I understand the scope of the partial match at a glance.

#### Acceptance Criteria

1. WHEN the file count exceeds the matched album's track count, THE Lookup_Apply_Panel SHALL display a summary in the format "{matched} of {total} files matched to tracks • {unmatched} files will receive album info only".
2. WHEN all files are matched (file count equals or is less than track count), THE Lookup_Apply_Panel SHALL display a summary in the format "{total} file(s) matched".

### Requirement 9: Track Number Denominator from Actual File Count

**User Story:** As a user, I want track numbers to reflect my actual album size (e.g. "3/16" not "3/11"), so that the metadata accurately represents my complete collection.

#### Acceptance Criteria

1. WHEN the user applies a partial match with track number selected, THE Partial_Match_Applicator SHALL format the track number denominator as the Total_File_Count.
2. WHEN the user has selected a subset of files for track assignment, THE Partial_Match_Applicator SHALL use the total number of selected local files as the denominator.
3. WHEN the user applies a full (non-partial) match, THE Partial_Match_Applicator SHALL format the track number denominator as the Matched_Track_Count to preserve existing behaviour.

### Requirement 10: Track Number Position Assignment

**User Story:** As a user, I want the track position (numerator) to come from the album track data for matched files, so that the ordering matches the official release.

#### Acceptance Criteria

1. WHEN a file is assigned to an album track, THE Partial_Match_Applicator SHALL use that album track's position as the track number numerator.
2. WHEN a file has no track assignment, THE Partial_Match_Applicator SHALL leave the track number unchanged on that file.

### Requirement 11: Partial Match Activation

**User Story:** As a user, I want to apply an album match even when it has fewer tracks than my files, so that I can use standard edition metadata for special/deluxe edition albums.

#### Acceptance Criteria

1. WHEN a selected album result has fewer tracks than the number of selected local files, THE Lookup_Dialog SHALL offer a "Apply as Partial Match" action.
2. WHEN the user activates "Apply as Partial Match", THE Lookup_Dialog SHALL transition to the partial match workflow instead of requiring an exact track count match.
3. WHEN a selected album result has equal or more tracks than the number of selected local files, THE Lookup_Dialog SHALL use the existing full-match workflow without change.

### Requirement 12: Partial Match Preview

**User Story:** As a user, I want to preview which fields will change on each file before applying, so that I can verify the partial match is correct.

#### Acceptance Criteria

1. WHEN the partial match workflow is active, THE Lookup_Apply_Panel SHALL display a preview showing proposed changes per file.
2. THE Lookup_Apply_Panel SHALL display the formatted Track_Number_Format (with correct denominator) in the preview for assigned files.
3. THE Lookup_Apply_Panel SHALL show "(no change)" for Track_Metadata fields on unmatched file rows.

### Requirement 13: Match Confidence Indicators

**User Story:** As a user, I want to see how confident the matcher is about each pairing, so that I can spot and correct questionable matches before applying.

#### Acceptance Criteria

1. THE Lookup_Apply_Panel SHALL display a confidence indicator (e.g. high, medium, low) for each matched file based on the Match_Score.
2. WHEN a match has a low confidence score, THE Lookup_Apply_Panel SHALL highlight that row to draw user attention.
3. THE Lookup_Apply_Panel SHALL allow the user to reassign or clear a track assignment from any matched file.
