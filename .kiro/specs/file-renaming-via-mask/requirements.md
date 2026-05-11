# Requirements Document

## Introduction

File Renaming via Mask enables users of Open Tag Editor to batch-rename (and optionally relocate) audio files using a pattern built from metadata tag variables. The mask can include directory separators to reorganize files into folder hierarchies in a single operation. The feature provides a live preview, case transformation options, conflict resolution, and full undo support.

## Glossary

- **Renamer**: The subsystem responsible for parsing mask patterns, generating new file paths, and executing rename/move operations on audio files.
- **Mask**: A string pattern containing literal text and tag variable placeholders (e.g., `%artist`, `%title`) that defines the target filename or path for a rename operation.
- **Tag_Variable**: A placeholder token in a mask (prefixed with `%`) that resolves to a metadata tag value from an audio file (e.g., `%artist` resolves to the Artist tag).
- **Preview_Engine**: The component that evaluates a mask against a set of audio files and produces a list of current-path-to-new-path mappings without modifying the filesystem.
- **Conflict**: A condition where two or more files would resolve to the same target path after mask evaluation.
- **Case_Transformer**: The component that applies text case transformations (lowercase, uppercase, title case, sentence case) to resolved tag values.
- **Mask_Preset**: A named, user-saved mask pattern that can be recalled for reuse.
- **Rename_Command**: An undoable command object that encapsulates a batch rename operation, storing original and new paths for reversal.
- **Conflict_Resolution_Strategy**: The user-chosen action when a target file already exists: skip, overwrite, or auto-increment the filename.

## Requirements

### Requirement 1: Mask Pattern Parsing

**User Story:** As a user, I want to define a filename mask using tag variable placeholders, so that I can generate new filenames derived from my audio files' metadata.

#### Acceptance Criteria

1. THE Renamer SHALL support the following tag variables in mask patterns: `%artist`, `%title`, `%album`, `%year`, `%genre`, `%track`, `%totalTracks`, `%disc`, `%totalDiscs`, `%albumartist`, `%comment`, `%bpm`, `%composer`, `%conductor`, `%filename`, `%ext`, and `%ignore`.
2. WHEN a mask pattern is evaluated against an audio file, THE Renamer SHALL replace each tag variable with the corresponding metadata value from that file.
3. WHEN the `%track` variable is resolved and the tag value contains a slash-separated format (e.g., "01/12"), THE Renamer SHALL extract only the portion before the slash and zero-pad it to at least two digits.
4. WHEN the `%track` variable is resolved and the tag value is a plain number, THE Renamer SHALL zero-pad the track number to at least two digits.
5. WHEN the `%track` variable is resolved and the tag value contains non-numeric content (e.g., "A1"), THE Renamer SHALL pass the value through as-is without modification.
6. WHEN the `%disc` variable is resolved and the tag value contains a slash-separated format (e.g., "1/2"), THE Renamer SHALL extract only the portion before the slash.
7. WHEN the `%disc` variable is resolved and the tag value does not contain a slash, THE Renamer SHALL pass the value through as-is.
8. WHEN the `%totalTracks` variable is resolved, THE Renamer SHALL extract the portion after the slash from the track tag value (e.g., "01/12" yields "12"). IF no slash is present, THE Renamer SHALL resolve to an empty string.
9. WHEN the `%totalDiscs` variable is resolved, THE Renamer SHALL extract the portion after the slash from the disc tag value (e.g., "1/2" yields "2"). IF no slash is present, THE Renamer SHALL resolve to an empty string.
8. WHEN the `%year` variable is resolved and the tag value contains a full date (e.g., "2023-05-14"), THE Renamer SHALL extract only the four-digit year portion.
9. WHEN the `%year` variable is resolved and the tag value is a two-digit or other non-date format, THE Renamer SHALL pass the value through as-is.
10. WHEN the `%bpm` variable is resolved, THE Renamer SHALL pass the value through as-is (including floats or approximate values).
11. WHEN the `%comment` variable is resolved, THE Renamer SHALL truncate the value to a maximum of 64 characters to prevent excessively long filenames.
12. FOR ALL resolved tag values, THE Renamer SHALL trim leading and trailing whitespace before substitution.
13. WHEN a tag variable resolves to an empty string and the mask contains literal delimiters adjacent to that variable (e.g., ` - ` between two variables), THE Renamer SHALL collapse orphaned delimiters to avoid artifacts like leading/trailing separators or double separators in the output.
14. WHEN the `%filename` variable is resolved, THE Renamer SHALL substitute the original filename without its extension.
15. WHEN the `%ext` variable is resolved, THE Renamer SHALL substitute the file extension without the leading dot.
16. WHEN a tag variable resolves to an empty string, THE Renamer SHALL substitute an empty string for that variable in the output.
17. WHEN the `%ignore` variable appears in a mask, THE Renamer SHALL discard that segment and any adjacent literal separators from the output (e.g., in `%track - %ignore - %title`, the ignored segment and its surrounding delimiters are removed, producing `%track - %title`).
18. FOR ALL valid mask patterns, parsing then formatting then parsing SHALL produce an equivalent mask structure (round-trip property).

### Requirement 2: Full-Path Masks and Folder Creation

**User Story:** As a user, I want my mask to include folder separators so that files are moved into an organized directory hierarchy during the rename operation.

#### Acceptance Criteria

1. WHEN a mask contains directory separator characters, THE Renamer SHALL interpret the portion before the final separator as the target directory path.
2. WHEN the target directory does not exist on the filesystem, THE Renamer SHALL create all missing directories recursively before moving the file.
3. WHEN a rename operation moves a file to a new path, THE Renamer SHALL remove the file from its original location (move semantics, not copy).
4. WHEN the target path already contains a file with the same name and the user selects "skip", THE Renamer SHALL leave the source file unchanged.
5. WHEN the target path already contains a file with the same name and the user selects "overwrite", THE Renamer SHALL replace the existing target file with the source file.
6. WHEN the target path already contains a file with the same name and the user selects "auto-increment", THE Renamer SHALL append a numeric suffix to the filename to make it unique.

### Requirement 3: Rename Preview

**User Story:** As a user, I want to see a preview of all filename changes before committing, so that I can verify the mask produces the expected results.

#### Acceptance Criteria

1. WHEN the user activates the preview action, THE Preview_Engine SHALL display a two-column list showing each file's current path and its computed new path.
2. WHEN two or more files resolve to the same target path, THE Preview_Engine SHALL highlight those entries as conflicts.
3. WHEN a mask produces an empty or invalid filename for a file, THE Preview_Engine SHALL flag that entry with an error indicator.
4. WHEN the mask pattern or case options change, THE Preview_Engine SHALL regenerate the preview automatically.
5. THE Preview_Engine SHALL generate previews for 500 files within 1 second.

### Requirement 4: Case Transformation Options

**User Story:** As a user, I want to apply case transformations to the resolved tag values, so that my filenames follow a consistent capitalization style.

#### Acceptance Criteria

1. WHERE the "Replace underscores with spaces" option is enabled, THE Case_Transformer SHALL replace all underscore characters with space characters in resolved tag values.
2. WHERE the "lowercase" case option is selected, THE Case_Transformer SHALL convert all resolved tag values to lowercase.
3. WHERE the "UPPERCASE" case option is selected, THE Case_Transformer SHALL convert all resolved tag values to uppercase.
4. WHERE the "Capitalize First Letter" case option is selected, THE Case_Transformer SHALL capitalize the first letter of each word in resolved tag values.
5. WHERE the "Sentence case" case option is selected, THE Case_Transformer SHALL capitalize only the first letter of the first word in resolved tag values.
6. WHERE the "None" case option is selected, THE Case_Transformer SHALL leave resolved tag values unchanged.

### Requirement 5: Mask Presets

**User Story:** As a user, I want to save, name, and recall frequently used mask patterns, so that I do not have to retype them each time.

#### Acceptance Criteria

1. WHEN the user saves a mask pattern, THE Renamer SHALL persist the pattern with a user-provided name.
2. WHEN the user selects a saved preset, THE Renamer SHALL populate the mask input field with the stored pattern.
3. WHEN the user deletes a saved preset, THE Renamer SHALL remove it from the persisted list.
4. THE Renamer SHALL provide a set of built-in default presets that cannot be deleted.

### Requirement 6: Rename Execution

**User Story:** As a user, I want to execute the rename operation on all selected files with progress feedback, so that I know the operation's status and outcome.

#### Acceptance Criteria

1. WHEN the user activates the rename action, THE Renamer SHALL apply the mask to all selected files (or all visible files if none are selected).
2. WHILE a batch rename is in progress, THE Renamer SHALL display a progress indicator showing the number of files processed.
3. WHEN the batch rename completes, THE Renamer SHALL display a summary showing the count of files renamed, files skipped, and errors encountered.
4. THE Renamer SHALL perform a dry-run validation before executing any filesystem changes.

### Requirement 7: Undo Support

**User Story:** As a user, I want to undo a rename operation, so that I can revert files to their original names and locations if the result is not what I expected.

#### Acceptance Criteria

1. WHEN a batch rename completes successfully, THE Renamer SHALL register a Rename_Command with the undo/redo manager.
2. WHEN the user triggers undo on a Rename_Command, THE Renamer SHALL move each file back to its original path and restore its original filename.
3. THE Renamer SHALL preserve undo history for rename operations for the duration of the application session.

### Requirement 8: Safety Validations

**User Story:** As a user, I want the system to prevent rename operations that would result in data loss or invalid paths, so that my files remain safe.

#### Acceptance Criteria

1. IF the computed target path exceeds the operating system's maximum path length, THEN THE Renamer SHALL refuse to rename that file and report the error.
2. IF the target directory is outside the currently loaded folder, THEN THE Renamer SHALL warn the user that renamed files will no longer appear in the file list.
3. THE Renamer SHALL validate the complete resolved filename against the rules of the target filesystem (e.g., NTFS, ext4, APFS), rejecting characters and names that are illegal on that filesystem.
4. THE Renamer SHALL sanitize resolved filenames by removing or replacing characters that are invalid on the current operating system (e.g., `<>:"/\|?*` on Windows, `/` on Unix).
5. IF a mask produces a filename consisting entirely of whitespace or invalid characters, THEN THE Renamer SHALL refuse to rename that file and report the error.
6. THE Renamer SHALL reject filenames that match reserved OS names (e.g., CON, PRN, NUL on Windows).

### Requirement 9: Mask Editor Dialog

**User Story:** As a user, I want a visual mask editor that helps me build mask patterns by selecting tag variables from a list, so that I do not need to memorize placeholder syntax.

#### Acceptance Criteria

1. WHEN the user opens the mask editor, THE Renamer SHALL display a dialog listing all available tag variables with descriptions.
2. WHEN the user selects a tag variable from the list, THE Renamer SHALL insert the corresponding placeholder at the current cursor position in the mask input.
3. WHEN the user confirms the mask editor dialog, THE Renamer SHALL update the mask input field with the constructed pattern.

### Requirement 10: Performance

**User Story:** As a user, I want rename operations to complete quickly even for large batches, so that my workflow is not interrupted by long waits.

#### Acceptance Criteria

1. THE Renamer SHALL complete an in-place rename of 500 files within 10 seconds.
2. THE Preview_Engine SHALL generate previews for 500 files within 1 second.
