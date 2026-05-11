# Implementation Plan: Album Art Management

## Overview

Implement the complete album art write/remove workflow for Open Tag Editor. The approach starts with fixing the `AudioFile.copyWith` nullable art issue, then implements the FFI `writeAlbumArt` method, creates the `AlbumArtManager` service and `AlbumArtCommand` for undo support, rewrites the `_AlbumArtTab` widget with drop zone, clipboard paste, batch indicator, and preview modal. Each step builds incrementally with pure-logic components validated before widget integration.

## Tasks

- [x] 1. Fix AudioFile.copyWith and implement writeAlbumArt FFI
  - [x] 1.1 Add clearAlbumArt parameter to AudioFile.copyWith
    - Add `bool clearAlbumArt = false` parameter to `AudioFile.copyWith`
    - Update the `albumArt` assignment to: `albumArt: clearAlbumArt ? null : (albumArt ?? this.albumArt)`
    - File: `lib/shared/models/audio_file.dart`
    - _Requirements: 2.4_
    - _Subagent: delegate_

  - [x] 1.2 Implement TagLibWriterService.writeAlbumArt via FFI
    - Replace the TODO/throw in `writeAlbumArt` with a working implementation
    - Construct a `TagLib_Complex_Property_Attribute` array with entries for: data (ByteVector), mimeType (String), description (String), pictureType (String)
    - Use `taglib_complex_property_set(file, "PICTURE", attributes)` to write
    - Use atomic writes via `_atomicWriteManager.writeAtomic`
    - Free all native memory in try/finally blocks
    - File: `lib/shared/services/taglib/taglib_writer_service.dart`
    - _Requirements: 1.2_
    - _Subagent: main thread (complex logic)_ — FFI memory management with complex struct arrays

  - [x] 1.3 Add FFI bindings for TagLib_Complex_Property_Attribute and TagLib_Variant
    - Add `TagLib_Complex_Property_Attribute` struct binding (key + TagLib_Variant value)
    - Add `TagLib_Variant` struct binding (type enum + union value)
    - Add `TagLib_Variant_Type` constants
    - Add helper to build a null-terminated attribute array for picture data
    - File: `lib/shared/services/taglib/taglib_bindings.g.dart`
    - _Requirements: 1.2_
    - _Subagent: main thread (complex logic)_ — FFI struct layout must match C header exactly

- [x] 2. Create AlbumArtManager service and AlbumArtCommand
  - [x] 2.1 Create BatchProgress and BatchFailure data classes
    - Create `lib/features/album_art/data/models/batch_progress.dart`
    - Implement `BatchProgress` with completed, total, failures, currentFile, isComplete, hasFailures
    - Implement `BatchFailure` with path and error
    - _Requirements: 4.2, 4.3_
    - _Subagent: delegate_

  - [x] 2.2 Create AlbumArtCommand undoable command
    - Create `lib/features/album_art/data/album_art_command.dart`
    - Implement `AlbumArtCommand` extending `UndoableCommand`
    - Store `previousArtMap` (Map<String, AlbumArtData?>) and `newArt` (AlbumArtData?)
    - `execute()`: write newArt to all files (or remove if null), update FileListNotifier
    - `undo()`: restore previousArtMap state for each file, update FileListNotifier
    - Handle the `clearAlbumArt` flag in copyWith for remove operations
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
    - _Subagent: delegate_

  - [x] 2.3 Create AlbumArtManager service
    - Create `lib/features/album_art/data/album_art_manager.dart`
    - Implement `addAlbumArt` method: validate image, check size warning threshold (5 MB), write to each file, emit progress, register undo command
    - Implement `removeAlbumArt` method: remove from each file, emit progress, register undo command
    - Continue processing on per-file failures, aggregate into BatchProgress.failures
    - _Requirements: 1.2, 1.3, 1.5, 2.1, 2.3, 4.1, 4.2, 4.3, 4.4_
    - _Subagent: delegate_

  - [x] 2.4 Create album art providers
    - Create `lib/features/album_art/data/providers/album_art_providers.dart`
    - Create `albumArtManagerProvider` that depends on `tagWriterProvider`, `fileListProvider.notifier`, and `undoRedoProvider.notifier`
    - _Requirements: 1.2, 2.1_
    - _Subagent: delegate_

- [x] 3. Implement image validation and mixed art detection
  - [x] 3.1 Create image validation utility
    - Create `lib/features/album_art/data/image_validator.dart`
    - Implement `isValidImageMimeType(String mimeType)` — accepts jpeg, png, bmp, gif, webp
    - Implement `detectMimeType(Uint8List bytes)` — detect from magic bytes (JPEG: FF D8, PNG: 89 50 4E 47, etc.)
    - Implement `exceedsSizeThreshold(int bytes)` — returns true if > 5,242,880
    - Implement `getImageDimensions(Uint8List bytes)` — returns (width, height) using the `image` package
    - _Requirements: 1.1, 1.5, 5.3, 7.1_
    - _Subagent: delegate_

  - [x] 3.2 Create mixed art detection utility
    - Create `lib/features/album_art/data/mixed_art_detector.dart`
    - Implement `detectArtState(List<AudioFile> files)` returning `ArtDisplayState` enum: `single`, `shared`, `mixed`, `none`
    - `single`: exactly one file selected, show its art (or placeholder)
    - `shared`: multiple files, all have identical art bytes
    - `mixed`: multiple files with different art (or some with/without)
    - `none`: single file with no art, or all files have no art
    - _Requirements: 8.1, 8.2, 8.3, 8.4_
    - _Subagent: delegate_

- [x] 4. Rewrite _AlbumArtTab widget with full functionality
  - [x] 4.1 Create DropZoneWrapper widget
    - Create `lib/features/album_art/presentation/widgets/drop_zone_wrapper.dart`
    - Use `desktop_drop` package's `DropTarget` widget
    - Show border highlight (2px solid primary color) when dragging over
    - On drop: read file bytes, validate image type, call `onImageDropped` callback
    - On invalid drop: show error snackbar
    - Remove highlight when drag leaves
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
    - _Subagent: delegate_

  - [x] 4.2 Create ImagePreviewModal dialog
    - Create `lib/features/album_art/presentation/widgets/image_preview_modal.dart`
    - Full-screen dialog with dark overlay background
    - Display album art at full resolution with `InteractiveViewer` for zoom/pan
    - Close on tap outside the image area
    - Close on Escape key press
    - Show image dimensions and file size in a bottom bar
    - _Requirements: 7.2, 7.3_
    - _Subagent: delegate_

  - [x] 4.3 Create BatchProgressOverlay widget
    - Create `lib/features/album_art/presentation/widgets/batch_progress_overlay.dart`
    - Overlay on the album art panel during batch operations
    - Show linear progress bar with "Processing X of Y files" text
    - On completion: show summary (N succeeded, M failed) for 3 seconds then dismiss
    - _Requirements: 4.2, 4.3_
    - _Subagent: delegate_

  - [x] 4.4 Rewrite _AlbumArtTab with all features integrated
    - Rewrite `_AlbumArtTab` in `lib/features/tag_editor/presentation/widgets/tag_edit_panel.dart`
    - Wrap content in `DropZoneWrapper` for drag-and-drop
    - Add `KeyboardListener` for Ctrl+V clipboard paste
    - Wire Add button to `AlbumArtManager.addAlbumArt` via file picker
    - Wire Remove button to `AlbumArtManager.removeAlbumArt` with confirmation dialog for multi-file
    - Show batch indicator (shared art / mixed / placeholder) based on `detectArtState`
    - Show image resolution alongside existing size/MIME info
    - Make thumbnail clickable to open `ImagePreviewModal`
    - Show size warning dialog when image exceeds 5 MB
    - Show batch progress overlay during operations
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 4.2, 4.3, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 8.1, 8.2, 8.3, 8.4_
    - _Subagent: main thread (cross-file wiring)_ — integrates all components, requires understanding of existing widget structure

- [x] 5. Add desktop_drop and image package dependencies
  - [x] 5.1 Add desktop_drop and image packages to pubspec.yaml
    - Add `desktop_drop: ^0.5.0` to dependencies
    - Add `image: ^4.3.0` to dependencies
    - Run `flutter pub get`
    - _Requirements: 5.1, 7.1_
    - _Subagent: delegate_

- [x] 6. Checkpoint - Verify build and analyze
  - Run `flutter analyze` and `flutter build windows` to verify no errors.
  - Fix any issues before proceeding.

- [ ] 7. Write tests
  - [ ]* 7.1 Write property tests for album art operations
    - Create `test/features/album_art/album_art_properties_test.dart`
    - Property 1: Undo add restores previous art state
    - Property 2: Undo remove restores original art
    - Property 3: Batch progress completeness
    - Property 4: Mixed art detection correctness
    - Property 5: Image validation (valid/invalid MIME types)
    - Property 6: Large image warning threshold
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 8.1, 8.2, 8.3, 8.4, 1.1, 1.5_
    - _Subagent: delegate_

  - [ ]* 7.2 Write unit tests for AlbumArtManager
    - Create `test/features/album_art/album_art_manager_test.dart`
    - Test addAlbumArt: single file, multiple files, file with existing art
    - Test removeAlbumArt: single file, multiple files
    - Test batch failure handling: one file fails, others succeed
    - Test undo/redo integration
    - _Requirements: 1.2, 2.1, 4.1, 4.4_
    - _Subagent: delegate_

  - [ ]* 7.3 Write unit tests for image validation and mixed art detection
    - Create `test/features/album_art/image_validator_test.dart`
    - Create `test/features/album_art/mixed_art_detector_test.dart`
    - Test valid MIME types, invalid types, size threshold, dimension reading
    - Test all ArtDisplayState cases
    - _Requirements: 1.1, 1.5, 8.1, 8.2, 8.3, 8.4_
    - _Subagent: delegate_

  - [ ]* 7.4 Write widget tests for album art UI
    - Create `test/features/album_art/album_art_tab_test.dart`
    - Test Add button triggers file picker
    - Test Remove button shows confirmation for multi-file
    - Test thumbnail click opens preview modal
    - Test batch indicator shows correct state
    - Test progress overlay appears during batch operations
    - _Requirements: 1.1, 2.2, 7.2, 8.1, 4.2_
    - _Subagent: delegate_

- [x] 8. Final checkpoint - Ensure all tests pass and build succeeds
  - Run `flutter analyze`, `flutter test`, and `flutter build windows`.
  - Fix any issues before marking complete.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The `writeAlbumArt` FFI implementation (task 1.2/1.3) is the most complex piece — it requires constructing a `TagLib_Complex_Property_Attribute` array in native memory
- The `desktop_drop` package must be added before the DropZoneWrapper widget can compile (task 5.1 before 4.1)
- `removeAlbumArt` is already fully implemented in `TagLibWriterService` — only `writeAlbumArt` needs FFI work
- The `AudioFile.copyWith` fix (task 1.1) is a prerequisite for the undo command's remove-undo path

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3", "5.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "3.1", "3.2"] },
    { "id": 2, "tasks": ["2.2", "2.4"] },
    { "id": 3, "tasks": ["2.3"] },
    { "id": 4, "tasks": ["4.1", "4.2", "4.3"] },
    { "id": 5, "tasks": ["4.4"] },
    { "id": 6, "tasks": ["7.1", "7.2", "7.3", "7.4"] }
  ]
}
```
