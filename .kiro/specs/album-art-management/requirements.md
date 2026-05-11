# Requirements Document

## Introduction

Album Art Management completes the album art write/remove workflow in Open Tag Editor so the existing UI buttons deliver on their promise. The feature enables users to add, remove, and preview album art across one or many selected audio files using file picker, drag-and-drop, and clipboard paste input methods. All operations are undoable and provide batch progress feedback.

## Glossary

- **Album_Art_Manager**: The subsystem responsible for coordinating album art add, remove, preview, and batch operations across selected audio files.
- **TagWriterService**: The service interface that performs low-level album art writing and removal on audio files via TagLib FFI.
- **AlbumArtData**: The data model holding image bytes, MIME type, description, and art type for an embedded album art image.
- **Album_Art_Command**: An undoable command object that encapsulates an album art add or remove operation, storing previous art state for reversal.
- **Drop_Zone**: The visual region of the Album Art panel that accepts dragged image files and provides hover feedback.
- **Batch_Indicator**: A UI element that communicates whether multiple selected files share the same album art or have mixed/different art.
- **Image_Preview_Modal**: A dialog that displays the full-resolution album art image when the user clicks the thumbnail.

## Requirements

### Requirement 1: Add Album Art via File Picker

**User Story:** As a user, I want to add album art by selecting an image file, so that I can embed cover art into my audio files.

#### Acceptance Criteria

1. WHEN the user clicks the "Add" button, THE Album_Art_Manager SHALL open a file picker dialog filtered to image types (JPEG, PNG, BMP, GIF, WebP).
2. WHEN the user selects a valid image file from the picker, THE Album_Art_Manager SHALL read the image bytes and write them to all currently selected audio files via TagWriterService.writeAlbumArt.
3. WHEN album art is written to a file, THE Album_Art_Manager SHALL update the in-memory AudioFile model with the new AlbumArtData.
4. WHEN the user cancels the file picker dialog, THE Album_Art_Manager SHALL take no action and leave existing art unchanged.
5. IF the selected image file exceeds 5 MB in size, THEN THE Album_Art_Manager SHALL display a warning to the user before proceeding with the write.

### Requirement 2: Remove Album Art

**User Story:** As a user, I want to remove album art from my audio files, so that I can clear unwanted or incorrect cover images.

#### Acceptance Criteria

1. WHEN the user clicks the "Remove" button with a single file selected, THE Album_Art_Manager SHALL call TagWriterService.removeAlbumArt on that file.
2. WHEN the user clicks the "Remove" button with multiple files selected, THE Album_Art_Manager SHALL display a confirmation prompt before proceeding.
3. WHEN the user confirms removal for multiple files, THE Album_Art_Manager SHALL call TagWriterService.removeAlbumArt on each selected file.
4. WHEN album art is removed from a file, THE Album_Art_Manager SHALL update the in-memory AudioFile model to clear the albumArt field.
5. WHEN the user dismisses the confirmation prompt, THE Album_Art_Manager SHALL take no action.

### Requirement 3: Undo Support for Album Art Operations

**User Story:** As a user, I want to undo album art add and remove operations, so that I can revert accidental changes.

#### Acceptance Criteria

1. WHEN an album art add operation completes, THE Album_Art_Manager SHALL register a single Album_Art_Command with the UndoRedoManager.
2. WHEN an album art remove operation completes, THE Album_Art_Manager SHALL register a single Album_Art_Command with the UndoRedoManager.
3. WHEN the user triggers undo on an Album_Art_Command that added art, THE Album_Art_Manager SHALL restore the previous album art state (including null if there was no prior art) for each affected file.
4. WHEN the user triggers undo on an Album_Art_Command that removed art, THE Album_Art_Manager SHALL restore the original album art data for each affected file.
5. WHEN a batch operation affects multiple files, THE Album_Art_Manager SHALL register it as a single undoable command (not one per file).

### Requirement 4: Batch Operations and Progress

**User Story:** As a user, I want album art operations to apply to all selected files with progress feedback, so that I can efficiently manage art across an album.

#### Acceptance Criteria

1. WHEN multiple files are selected and an add operation is triggered, THE Album_Art_Manager SHALL write the album art to each selected file.
2. WHILE a batch album art operation is in progress, THE Album_Art_Manager SHALL display a progress indicator showing the number of files processed out of the total.
3. WHEN a batch operation completes, THE Album_Art_Manager SHALL display a summary of successes and failures.
4. IF a write fails for one file in a batch, THEN THE Album_Art_Manager SHALL continue processing remaining files and report the failure in the summary.
5. THE Album_Art_Manager SHALL complete writing album art to 50 files within 10 seconds.

### Requirement 5: Drag-and-Drop

**User Story:** As a user, I want to drag an image file onto the Album Art panel to set it as cover art, so that I have a quick alternative to the file picker.

#### Acceptance Criteria

1. WHEN the user drags an image file over the Album Art panel, THE Drop_Zone SHALL display a visual indicator showing the panel accepts the drop.
2. WHEN the user drops a valid image file onto the Album Art panel, THE Album_Art_Manager SHALL read the image and write it to all selected audio files.
3. WHEN the user drops a non-image file onto the Album Art panel, THE Album_Art_Manager SHALL reject the drop and display an error message.
4. WHEN the drag leaves the Album Art panel without dropping, THE Drop_Zone SHALL remove the visual indicator.

### Requirement 6: Clipboard Paste

**User Story:** As a user, I want to paste an image from my clipboard as album art, so that I can quickly apply art copied from other applications.

#### Acceptance Criteria

1. WHEN the user presses Ctrl+V while the Album Art tab is focused and the clipboard contains image data, THE Album_Art_Manager SHALL read the image data and write it to all selected audio files.
2. WHEN the user presses Ctrl+V while the Album Art tab is focused and the clipboard contains a file path to a valid image, THE Album_Art_Manager SHALL read the referenced image file and write it to all selected audio files.
3. WHEN the user presses Ctrl+V and the clipboard contains neither image data nor a valid image file path, THE Album_Art_Manager SHALL take no action.

### Requirement 7: Image Preview

**User Story:** As a user, I want to see image dimensions and view the full-size art, so that I can verify the quality and content of embedded cover art.

#### Acceptance Criteria

1. WHEN album art is displayed in the panel, THE Album_Art_Manager SHALL show the image resolution (width x height pixels) alongside the existing size and MIME type information.
2. WHEN the user clicks the album art thumbnail, THE Image_Preview_Modal SHALL open displaying the full-resolution image.
3. WHEN the Image_Preview_Modal is open, THE Image_Preview_Modal SHALL allow the user to close it by clicking outside or pressing Escape.

### Requirement 8: Batch Indicator for Mixed Art

**User Story:** As a user, I want to see whether my selected files share the same album art, so that I know the current state before making changes.

#### Acceptance Criteria

1. WHEN multiple files are selected and all share identical album art bytes, THE Batch_Indicator SHALL display that shared album art image.
2. WHEN multiple files are selected and they have different album art, THE Batch_Indicator SHALL display a "mixed" indicator instead of any single image.
3. WHEN multiple files are selected and some have art while others do not, THE Batch_Indicator SHALL display the "mixed" indicator.
4. WHEN a single file is selected, THE Album_Art_Manager SHALL display that file's album art (or an empty placeholder if none exists).
