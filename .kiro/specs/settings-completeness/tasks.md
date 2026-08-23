# Implementation Plan: Settings Completeness

## Overview

Wire all Settings page UI controls to persisted state via `shared_preferences` and ensure each setting actively influences application behavior. Introduces three section-specific StateNotifier providers (General, Tag Writing, Renaming) following the existing `LookupSettingsNotifier` pattern, a `TagWriteOptions` value object consumed by `TagLibWriterService` at write-time, and a confirmation dialog gating the save action.

## Tasks

- [x] 1. Create data models and enums
  - [x] 1.1 Create Id3v2Version and TagEncoding enums
    - Create `lib/features/settings/data/models/id3v2_version.dart` with `Id3v2Version` enum (v23, v24) including `displayName` and `numericVersion`
    - Create `lib/features/settings/data/models/tag_encoding.dart` with `TagEncoding` enum (utf8, utf16, latin1) including `displayName` and `id3v2EncodingByte`
    - _Requirements: 3.1, 6.1_

  - [x] 1.2 Create GeneralSettings immutable state class
    - Create `lib/features/settings/data/models/general_settings.dart`
    - Implement `GeneralSettings` with `confirmBeforeSaving` (default `true`) and `copyWith`
    - _Requirements: 1.1, 1.3_

  - [x] 1.3 Create TagWritingSettings immutable state class
    - Create `lib/features/settings/data/models/tag_writing_settings.dart`
    - Implement `TagWritingSettings` with `id3v2Version` (default v24), `writeId3v1` (default false), `encoding` (default utf8) and `copyWith`
    - _Requirements: 3.3, 5.3, 6.3_

  - [x] 1.4 Create RenamingSettings immutable state class
    - Create `lib/features/settings/data/models/renaming_settings.dart`
    - Implement `RenamingSettings` with `defaultPattern` (default `'%artist% - %title%'`), `previewBeforeRenaming` (default `true`) and `copyWith`
    - _Requirements: 7.3, 8.3_

  - [x] 1.5 Create TagWriteOptions value object
    - Create `lib/features/settings/data/models/tag_write_options.dart`
    - Implement `TagWriteOptions` with `id3v2Version`, `writeId3v1`, `encoding` fields
    - _Requirements: 4.1, 5.4, 6.4_

- [x] 2. Implement StateNotifier providers
  - [x] 2.1 Implement GeneralSettingsNotifier
    - Create `lib/features/settings/data/notifiers/general_settings_notifier.dart`
    - Follow `LookupSettingsNotifier` pattern: versioned key `settings_v1_general_confirm_before_saving`
    - Implement `loadFromPrefs()` with try/catch and default fallback
    - Implement `setConfirmBeforeSaving(bool)` with immediate state emit + `_persist()`
    - _Requirements: 1.1, 1.2, 1.3, 9.1_

  - [x] 2.2 Implement TagWritingSettingsNotifier
    - Create `lib/features/settings/data/notifiers/tag_writing_settings_notifier.dart`
    - Versioned keys: `settings_v1_tagwriting_id3v2_version`, `settings_v1_tagwriting_write_id3v1`, `settings_v1_tagwriting_encoding`
    - Implement `loadFromPrefs()` with try/catch and default fallbacks per field
    - Implement `setId3v2Version(Id3v2Version)`, `setWriteId3v1(bool)`, `setEncoding(TagEncoding)`
    - Each setter emits new state immediately + calls `_persist()`
    - _Requirements: 3.1, 3.2, 3.3, 5.1, 5.2, 5.3, 6.1, 6.2, 6.3, 9.1_

  - [x] 2.3 Implement RenamingSettingsNotifier
    - Create `lib/features/settings/data/notifiers/renaming_settings_notifier.dart`
    - Versioned keys: `settings_v1_renaming_default_pattern`, `settings_v1_renaming_preview_before_renaming`
    - Implement `loadFromPrefs()` with try/catch and default fallbacks
    - Implement `setDefaultPattern(String)`, `setPreviewBeforeRenaming(bool)`
    - Each setter emits new state immediately + calls `_persist()`
    - _Requirements: 7.1, 7.2, 7.3, 8.1, 8.2, 8.3, 9.1_

  - [x] 2.4 Create Riverpod provider definitions
    - Create `lib/features/settings/data/providers/settings_providers.dart`
    - Define `generalSettingsProvider` as `StateNotifierProvider<GeneralSettingsNotifier, GeneralSettings>`
    - Define `tagWritingSettingsProvider` as `StateNotifierProvider<TagWritingSettingsNotifier, TagWritingSettings>`
    - Define `renamingSettingsProvider` as `StateNotifierProvider<RenamingSettingsNotifier, RenamingSettings>`
    - _Requirements: 9.1, 10.2_

  - [ ]* 2.5 Write property test for GeneralSettings persistence round-trip
    - **Property 1: GeneralSettings persistence round-trip**
    - Create `test/features/settings/data/general_settings_notifier_test.dart`
    - For any boolean value, persist then load produces identical state
    - Use `package:fast_check` with minimum 100 iterations
    - **Validates: Requirements 1.1, 1.2**

  - [ ]* 2.6 Write property test for TagWritingSettings persistence round-trip
    - **Property 2: TagWritingSettings persistence round-trip**
    - Create `test/features/settings/data/tag_writing_settings_notifier_test.dart`
    - For any combination of Id3v2Version, writeId3v1 bool, and TagEncoding, persist then load produces identical state
    - Use `package:fast_check` with minimum 100 iterations
    - **Validates: Requirements 3.1, 3.2, 5.1, 5.2, 6.1, 6.2**

  - [ ]* 2.7 Write property test for RenamingSettings persistence round-trip
    - **Property 3: RenamingSettings persistence round-trip**
    - Create `test/features/settings/data/renaming_settings_notifier_test.dart`
    - For any non-empty pattern string and boolean previewBeforeRenaming, persist then load produces identical state
    - Use `package:fast_check` with minimum 100 iterations
    - **Validates: Requirements 7.1, 7.2, 8.1, 8.2**

- [x] 3. Integrate TagWriteOptions into TagLibWriterService
  - [x] 3.1 Add TagWriteOptions callback to TagLibWriterService constructor
    - Modify `lib/shared/services/taglib/taglib_writer_service.dart`
    - Add `required TagWriteOptions Function() getWriteOptions` parameter
    - Store as `_getWriteOptions` field
    - In `writeTags()`, call `_getWriteOptions()` to get current options
    - Apply ID3v2 version, encoding, and ID3v1 flag during write
    - Handle v2.3 + UTF-8 incompatibility by falling back to UTF-16
    - _Requirements: 4.1, 4.2, 5.4, 5.5, 6.4, 9.3_

  - [x] 3.2 Update tagWriterProvider to inject TagWriteOptions callback
    - Modify the existing `tagWriterProvider` to pass `getWriteOptions` callback
    - Callback reads current state from `tagWritingSettingsProvider` via `ref.read`
    - _Requirements: 4.2, 9.3_

  - [ ]* 3.3 Write unit tests for TagLibWriterService options integration
    - Test that changing settings between writes results in different options being used
    - Test v2.3 + UTF-8 fallback to UTF-16
    - _Requirements: 4.1, 4.2, 6.4_

- [x] 4. Checkpoint - Verify providers and service integration
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement confirmation dialog and save action gating
  - [x] 5.1 Create PendingTagChange data class
    - Create `lib/features/settings/data/models/pending_tag_change.dart`
    - Implement `PendingTagChange` with `filePath` and `fieldChanges` (Map<String, String>)
    - _Requirements: 2.1_

  - [x] 5.2 Create ConfirmationDialog widget
    - Create `lib/features/settings/presentation/widgets/confirmation_dialog.dart`
    - Display list of file paths with change summaries (field name → new value)
    - Confirm button returns `true`, Cancel button returns `false`
    - Dismiss via back button/outside tap treated as cancel
    - Handle empty change set edge case (return true immediately)
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 5.3 Integrate confirmation dialog into save action flow
    - Modify the save action orchestrator to check `generalSettingsProvider.confirmBeforeSaving`
    - If enabled: show `ConfirmationDialog` with pending changes, proceed or abort based on result
    - If disabled: proceed with write immediately
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ]* 5.4 Write property test for confirmation dialog content completeness
    - **Property 4: Confirmation dialog content completeness**
    - Create `test/features/settings/presentation/confirmation_dialog_test.dart`
    - For any non-empty set of PendingTagChange objects, rendered content includes every file path and every changed field with its new value
    - Use `package:fast_check` with minimum 100 iterations
    - **Validates: Requirements 2.1**

  - [ ]* 5.5 Write unit tests for save action gating
    - Test dialog shown when confirmBeforeSaving is true
    - Test dialog skipped when confirmBeforeSaving is false
    - Test cancel aborts write, confirm proceeds
    - _Requirements: 2.2, 2.3, 2.4_

- [x] 6. Wire Settings page UI to providers
  - [x] 6.1 Wire General section of Settings page
    - Modify `lib/features/settings/presentation/pages/settings_page.dart`
    - Replace TODO placeholder for "confirm before saving" toggle with a `Switch` widget bound to `generalSettingsProvider`
    - On toggle: call `ref.read(generalSettingsProvider.notifier).setConfirmBeforeSaving(value)`
    - _Requirements: 1.4, 9.2_

  - [x] 6.2 Wire Tag Writing section of Settings page
    - Add ID3v2 version dropdown/picker bound to `tagWritingSettingsProvider.id3v2Version`
    - Add "Write ID3v1 tags" switch bound to `tagWritingSettingsProvider.writeId3v1`
    - Add encoding dropdown/picker bound to `tagWritingSettingsProvider.encoding`
    - On change: call corresponding setter on `tagWritingSettingsProvider.notifier`
    - _Requirements: 3.4, 5.1, 6.5, 9.2_

  - [x] 6.3 Wire Renaming section of Settings page
    - Add default pattern text field bound to `renamingSettingsProvider.defaultPattern`
    - Add "Preview before renaming" switch bound to `renamingSettingsProvider.previewBeforeRenaming`
    - On change: call corresponding setter on `renamingSettingsProvider.notifier`
    - _Requirements: 7.5, 8.1, 9.2_

  - [x] 6.4 Wire rename dialog to read default pattern from provider
    - Modify the rename dialog to pre-fill the mask input with `ref.read(renamingSettingsProvider).defaultPattern`
    - Respect `previewBeforeRenaming` setting: if disabled, allow direct execution without mandatory preview
    - _Requirements: 7.4, 8.4, 8.5_

  - [ ]* 6.5 Write widget tests for Settings page
    - Test each section displays current values from its notifier
    - Test toggle interactions update the notifier
    - Test picker dialogs update the notifier on selection
    - _Requirements: 1.4, 3.4, 6.5, 7.5, 9.2_

- [x] 7. Initialize settings on app startup
  - [x] 7.1 Call loadFromPrefs() for all settings notifiers at app startup
    - Modify app initialization to call `loadFromPrefs()` on all three notifiers
    - Ensure loading is asynchronous and does not block UI thread
    - Follow existing pattern used by `LookupSettingsNotifier`
    - _Requirements: 1.2, 3.2, 5.2, 6.2, 7.2, 8.2, 10.1, 10.2_

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The existing `LookupSettingsNotifier` in `lib/features/online_lookup/data/providers/lookup_settings_provider.dart` serves as the reference pattern for all new notifiers
- `backupEnabledProvider` (currently a simple `StateProvider<bool>`) is not migrated in this feature — it remains as-is

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4", "1.5"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "2.4"] },
    { "id": 2, "tasks": ["2.5", "2.6", "2.7", "3.1", "5.1"] },
    { "id": 3, "tasks": ["3.2", "3.3", "5.2"] },
    { "id": 4, "tasks": ["5.3", "5.4", "5.5", "6.1", "6.2", "6.3"] },
    { "id": 5, "tasks": ["6.4", "6.5", "7.1"] }
  ]
}
```
