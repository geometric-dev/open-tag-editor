# Requirements Document

## Introduction

Tags from Filename enables users to parse audio file paths and filenames using a mask pattern and populate tag fields from extracted segments. This is the inverse of the file renaming feature — instead of building filenames from tags, it extracts tags from filenames. The feature reuses the same mask syntax and variable definitions as the renamer, providing a consistent user experience across both directions of the tags-to-filename relationship.

## Glossary

- **Tag_Extractor**: The subsystem responsible for parsing file paths against a mask pattern and extracting tag values from the matched segments.
- **Mask**: A string pattern containing literal text and tag variable placeholders (e.g., `%artist`, `%title`) that defines how a file path maps to tag fields. Uses the same syntax as the renamer feature.
- **Tag_Variable**: A placeholder token in a mask (prefixed with `%`) that identifies which tag field a path segment maps to (e.g., `%artist` maps a segment to the Artist tag).
- **Path_Scope**: The portion of the file path that the mask is matched against: filename only, relative path from loaded root folder, or full absolute path.
- **Preview_Table**: The component that displays extracted tag values per file in a tabular format before writing, allowing the user to review and deselect files.
- **Extraction_Result**: The set of tag field-value pairs extracted from a single file's path by matching it against the mask pattern.
- **Write_Command**: An undoable command object that encapsulates a batch tag-write operation, storing previous tag values for reversal.
- **Mask_Preset**: A named, user-saved mask pattern that can be recalled for reuse. Shared with the renamer feature where applicable.
- **Case_Transformer**: The component that applies text case transformations and string cleanup (underscore replacement, trimming) to extracted values before writing.

## Requirements

### Requirement 1: Mask-Based Path Parsing

**User Story:** As a user, I want to define a mask pattern that maps segments of a file path to tag fields, so that I can extract metadata from well-structured filenames and folder hierarchies.

#### Acceptance Criteria

1. THE Tag_Extractor SHALL support the following tag variables in mask patterns: `%artist`, `%title`, `%album`, `%year`, `%genre`, `%track`, `%totalTracks`, `%disc`, `%totalDiscs`, `%albumartist`, `%comment`, `%bpm`, `%composer`, `%conductor`, and `%ignore`.
2. WHEN a mask pattern is matched against a file path, THE Tag_Extractor SHALL use the literal characters in the mask (e.g., ` - `, `/`, `_`) as delimiters to split the path into segments.
3. WHEN a mask pattern is matched against a file path, THE Tag_Extractor SHALL assign each segment between delimiters to the corresponding tag variable in left-to-right order.
4. WHEN the mask contains the `%ignore` variable, THE Tag_Extractor SHALL discard the corresponding path segment without assigning it to any tag field.
5. WHEN two adjacent variables are separated by a multi-character literal delimiter (e.g., ` - `), THE Tag_Extractor SHALL match the full delimiter string as the split point.
6. WHEN a mask contains consecutive variable placeholders without a literal separator between them, THE Tag_Extractor SHALL report a parse error because segment boundaries cannot be determined.
7. THE Tag_Extractor SHALL strip the file extension from the path before matching the mask pattern.
8. WHEN a variable-length segment contains the same character sequence as a subsequent delimiter (e.g., artist name containing ` - `), THE Tag_Extractor SHALL use left-to-right greedy matching, assigning the longest possible value to the earlier variable up to the first occurrence of the next delimiter.
9. FOR ALL valid mask patterns, parsing then formatting then parsing SHALL produce an equivalent token structure (round-trip property).
10. THE Tag_Extractor SHALL reuse the MaskParser from the renamer feature to tokenize mask patterns into the same MaskToken structure.

### Requirement 2: Path Scope Selection

**User Story:** As a user, I want to choose which portion of the file path the mask applies to, so that I can extract tags from folder names, filenames, or both.

#### Acceptance Criteria

1. THE Tag_Extractor SHALL provide three path scope options: filename only, relative path from loaded root folder, and full absolute path.
2. WHEN "filename only" scope is selected, THE Tag_Extractor SHALL match the mask against only the file's name (without extension and without any directory components).
3. WHEN "relative path" scope is selected, THE Tag_Extractor SHALL match the mask against the file's path relative to the currently loaded root folder (without extension).
4. WHEN "absolute path" scope is selected, THE Tag_Extractor SHALL match the mask against the file's full filesystem path (without extension).
5. WHEN the mask contains directory separator characters (`/`), THE Tag_Extractor SHALL treat them as literal delimiters that split path components.

### Requirement 3: Extraction Preview

**User Story:** As a user, I want to preview the extracted tag values for all files before writing, so that I can verify the mask produces correct results and deselect files that did not match.

#### Acceptance Criteria

1. WHEN the user activates the preview action, THE Preview_Table SHALL display a row for each loaded file showing the extracted value for every tag variable present in the mask.
2. WHEN a file's path does not match the mask structure (wrong number of segments or missing delimiters), THE Preview_Table SHALL display that file's row as empty and visually highlight it as a non-match.
3. THE Preview_Table SHALL allow the user to deselect individual files to exclude them from the subsequent write operation.
4. WHEN the mask pattern, path scope, or transformation options change, THE Preview_Table SHALL regenerate the preview automatically.
5. THE Preview_Table SHALL generate extraction previews for 500 files within 1 second.

### Requirement 4: Write Extracted Tags

**User Story:** As a user, I want to write the extracted tag values to my audio files' metadata, so that the files have proper tags derived from their filenames and folder structure.

#### Acceptance Criteria

1. WHEN the user activates the "Write Tags" action, THE Tag_Extractor SHALL write the extracted values to the corresponding metadata fields of each selected file.
2. THE Tag_Extractor SHALL write only the tag fields that are present in the mask pattern, preserving all other existing tag values in the file.
3. WHERE the "overwrite existing tags" option is enabled, THE Tag_Extractor SHALL replace existing tag values with the extracted values.
4. WHERE the "only fill empty fields" option is enabled, THE Tag_Extractor SHALL write extracted values only to tag fields that are currently empty, leaving populated fields unchanged.
5. WHEN writing tags to a file, THE Tag_Extractor SHALL use the TagLib FFI integration for atomic writes with frame preservation.
6. THE Tag_Extractor SHALL complete tag writing for 500 files within 30 seconds.

### Requirement 5: Undo Support

**User Story:** As a user, I want to undo a tag-write operation, so that I can revert files to their previous tag values if the extraction produced incorrect results.

#### Acceptance Criteria

1. WHEN a batch tag-write completes successfully, THE Tag_Extractor SHALL register a Write_Command with the undo/redo manager containing the previous tag values for all modified files.
2. WHEN the user triggers undo on a Write_Command, THE Tag_Extractor SHALL restore each file's tag fields to their values prior to the write operation.
3. THE Tag_Extractor SHALL preserve undo history for tag-write operations for the duration of the application session.

### Requirement 6: Value Transformation Options

**User Story:** As a user, I want to apply text transformations to extracted values before writing, so that tag values are clean and consistently formatted regardless of filename conventions.

#### Acceptance Criteria

1. WHERE the "Replace underscores with spaces" option is enabled, THE Case_Transformer SHALL replace all underscore characters with space characters in extracted values before writing.
2. WHERE the "Trim whitespace" option is enabled, THE Case_Transformer SHALL remove leading and trailing whitespace from all extracted values before writing.
3. WHERE the "lowercase" case option is selected, THE Case_Transformer SHALL convert all extracted values to lowercase before writing.
4. WHERE the "UPPERCASE" case option is selected, THE Case_Transformer SHALL convert all extracted values to uppercase before writing.
5. WHERE the "Capitalize First Letter" case option is selected, THE Case_Transformer SHALL capitalize the first letter of each word in extracted values before writing.
6. WHERE the "Sentence case" case option is selected, THE Case_Transformer SHALL capitalize only the first letter of the first word in extracted values before writing.
7. WHERE the "None" case option is selected, THE Case_Transformer SHALL leave extracted values unchanged.

### Requirement 7: Mask Presets

**User Story:** As a user, I want to save and recall mask presets, so that I can quickly reuse patterns for common filename structures without retyping them.

#### Acceptance Criteria

1. WHEN the user saves a mask pattern, THE Tag_Extractor SHALL persist the pattern with a user-provided name to the shared preset pool.
2. WHEN the user selects a saved preset, THE Tag_Extractor SHALL populate the mask input field with the stored pattern.
3. WHEN the user deletes a user-created preset, THE Tag_Extractor SHALL remove it from the persisted list.
4. THE Tag_Extractor SHALL share the mask preset pool with the renamer feature, allowing presets created in either feature to be used in both.
5. THE Tag_Extractor SHALL provide built-in default presets suitable for common filename patterns (e.g., `%track - %title`, `%artist - %album/%track - %title`).

### Requirement 8: Non-Matching File Handling

**User Story:** As a user, I want files that don't match the mask to be clearly identified and gracefully skipped, so that I can focus on files that parsed correctly without worrying about errors.

#### Acceptance Criteria

1. WHEN a file's path does not contain enough segments to satisfy all variables in the mask, THE Tag_Extractor SHALL mark that file as a non-match and exclude it from writing.
2. WHEN a file's path does not contain the expected literal delimiters from the mask, THE Tag_Extractor SHALL mark that file as a non-match and exclude it from writing.
3. THE Preview_Table SHALL visually distinguish non-matching files from successfully matched files using a distinct highlight or indicator.
4. WHEN the user activates "Write Tags", THE Tag_Extractor SHALL skip all non-matching files without producing an error.
5. THE Preview_Table SHALL display the count of matched files and non-matched files in a summary.

### Requirement 9: Greedy Parsing Behavior

**User Story:** As a user, I want predictable parsing behavior when path segments contain characters that also appear as delimiters, so that I understand how ambiguous paths will be resolved.

#### Acceptance Criteria

1. WHEN a path segment contains the same character sequence as a mask delimiter, THE Tag_Extractor SHALL split at the first occurrence of the delimiter (left-to-right greedy matching for the leftmost variable).
2. WHEN the last variable in the mask has no trailing delimiter, THE Tag_Extractor SHALL assign all remaining text (after the last delimiter) to that variable.
3. WHEN a mask uses `/` as a delimiter and the path scope includes directory components, THE Tag_Extractor SHALL split on actual path separators to determine directory-level segments before applying intra-segment delimiters.

### Requirement 10: Track Number Handling

**User Story:** As a user, I want track numbers extracted from filenames to be stored correctly regardless of zero-padding, so that my tags are consistent.

#### Acceptance Criteria

1. WHEN the `%track` variable extracts a zero-padded numeric value (e.g., "03"), THE Tag_Extractor SHALL store the value as-is preserving the original formatting from the filename.
2. WHEN the `%track` variable extracts a non-padded numeric value (e.g., "3"), THE Tag_Extractor SHALL store the value as-is.
3. WHEN the `%track` variable extracts a non-numeric value (e.g., "A1"), THE Tag_Extractor SHALL store the value as-is without modification.
