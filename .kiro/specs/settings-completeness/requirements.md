# Requirements Document

## Introduction

Settings Persistence & Completeness ensures that every UI control on the Settings page is wired to persisted state via `shared_preferences` and that each setting actively influences application behavior. The feature introduces three section-specific StateNotifier providers (General, Tag Writing, Renaming) following the existing `LookupSettingsNotifier` pattern, and passes tag-writing preferences through to the TagLib FFI layer.

## Glossary

- **GeneralSettingsNotifier**: The StateNotifier responsible for persisting and exposing general application preferences (e.g., confirm-before-saving).
- **TagWritingSettingsNotifier**: The StateNotifier responsible for persisting and exposing tag-writing preferences (ID3v2 version, ID3v1 toggle, text encoding).
- **RenamingSettingsNotifier**: The StateNotifier responsible for persisting and exposing file-renaming preferences (default pattern, preview toggle).
- **TagLibWriterService**: The service that writes audio file tags via TagLib FFI bindings.
- **Settings_Page**: The Flutter UI page that displays all application settings controls.
- **Confirmation_Dialog**: A modal dialog shown before a save operation that lists affected file paths and a summary of tag field changes.
- **Preference_Key**: A versioned string key used to store a setting value in `shared_preferences`.

## Requirements

### Requirement 1: General Settings Persistence

**User Story:** As a user, I want my "confirm before saving" preference to be remembered across sessions, so that I do not have to re-enable it every time I open the app.

#### Acceptance Criteria

1. WHEN the user toggles the "confirm before saving" switch, THE GeneralSettingsNotifier SHALL persist the boolean value to `shared_preferences` using a versioned Preference_Key.
2. WHEN the application starts, THE GeneralSettingsNotifier SHALL load the persisted "confirm before saving" value from `shared_preferences`.
3. IF the "confirm before saving" Preference_Key is missing or corrupted, THEN THE GeneralSettingsNotifier SHALL default to `true`.
4. THE Settings_Page SHALL display the current persisted value of the "confirm before saving" toggle without blocking the UI thread.

### Requirement 2: Confirm-Before-Saving Behavior

**User Story:** As a user, I want a confirmation dialog before tag changes are written, so that I can review which files and fields will be modified before committing.

#### Acceptance Criteria

1. WHILE the "confirm before saving" setting is enabled, WHEN the user triggers a save action, THE Confirmation_Dialog SHALL display a list of file paths with a change summary showing which tag fields changed and their new values.
2. WHEN the user confirms the Confirmation_Dialog, THE TagLibWriterService SHALL proceed with writing the tag changes.
3. WHEN the user cancels the Confirmation_Dialog, THE TagLibWriterService SHALL abort the write operation and leave all files unchanged.
4. WHILE the "confirm before saving" setting is disabled, WHEN the user triggers a save action, THE TagLibWriterService SHALL execute the write immediately without showing the Confirmation_Dialog.

### Requirement 3: ID3v2 Version Setting Persistence

**User Story:** As a user, I want to choose between ID3v2.3 and ID3v2.4 as my default tag version, so that I can maintain compatibility with my preferred media players.

#### Acceptance Criteria

1. WHEN the user selects an ID3v2 version (ID3v2.3 or ID3v2.4), THE TagWritingSettingsNotifier SHALL persist the choice to `shared_preferences` using a versioned Preference_Key.
2. WHEN the application starts, THE TagWritingSettingsNotifier SHALL load the persisted ID3v2 version from `shared_preferences`.
3. IF the ID3v2 version Preference_Key is missing or corrupted, THEN THE TagWritingSettingsNotifier SHALL default to ID3v2.4.
4. THE Settings_Page SHALL display the currently persisted ID3v2 version value.

### Requirement 4: ID3v2 Version Behavioral Integration

**User Story:** As a user, I want my chosen ID3v2 version to be used when writing tags, so that my files are tagged in the format I selected.

#### Acceptance Criteria

1. WHEN the TagLibWriterService writes tags to an MP3 file, THE TagLibWriterService SHALL use the ID3v2 version specified by the TagWritingSettingsNotifier.
2. WHEN the ID3v2 version setting changes, THE TagLibWriterService SHALL use the updated version for all subsequent write operations without requiring an application restart.

### Requirement 5: Write ID3v1 Tags Setting

**User Story:** As a user, I want to control whether legacy ID3v1 tags are written alongside ID3v2, so that I can support older devices that only read ID3v1.

#### Acceptance Criteria

1. WHEN the user toggles the "Write ID3v1 tags" switch, THE TagWritingSettingsNotifier SHALL persist the boolean value to `shared_preferences` using a versioned Preference_Key.
2. WHEN the application starts, THE TagWritingSettingsNotifier SHALL load the persisted "Write ID3v1 tags" value from `shared_preferences`.
3. IF the "Write ID3v1 tags" Preference_Key is missing or corrupted, THEN THE TagWritingSettingsNotifier SHALL default to `false`.
4. WHILE the "Write ID3v1 tags" setting is enabled, WHEN the TagLibWriterService writes tags to an MP3 file, THE TagLibWriterService SHALL write both an ID3v2 tag block and an ID3v1 tag block.
5. WHILE the "Write ID3v1 tags" setting is disabled, WHEN the TagLibWriterService writes tags to an MP3 file, THE TagLibWriterService SHALL write only the ID3v2 tag block.

### Requirement 6: Default Encoding Setting

**User Story:** As a user, I want to choose the text encoding for ID3v2 frames, so that I can ensure proper character display across different software.

#### Acceptance Criteria

1. WHEN the user selects a text encoding (UTF-8, UTF-16, or Latin-1), THE TagWritingSettingsNotifier SHALL persist the choice to `shared_preferences` using a versioned Preference_Key.
2. WHEN the application starts, THE TagWritingSettingsNotifier SHALL load the persisted encoding value from `shared_preferences`.
3. IF the encoding Preference_Key is missing or corrupted, THEN THE TagWritingSettingsNotifier SHALL default to UTF-8.
4. WHEN the TagLibWriterService writes ID3v2 frames to an MP3 file, THE TagLibWriterService SHALL use the encoding specified by the TagWritingSettingsNotifier.
5. THE Settings_Page SHALL display the currently persisted encoding value.

### Requirement 7: Default Rename Pattern Setting

**User Story:** As a user, I want to set a default rename pattern, so that the rename dialog is pre-filled with my preferred pattern instead of a built-in preset.

#### Acceptance Criteria

1. WHEN the user edits the default rename pattern, THE RenamingSettingsNotifier SHALL persist the pattern string to `shared_preferences` using a versioned Preference_Key.
2. WHEN the application starts, THE RenamingSettingsNotifier SHALL load the persisted default rename pattern from `shared_preferences`.
3. IF the default rename pattern Preference_Key is missing or corrupted, THEN THE RenamingSettingsNotifier SHALL default to the first built-in preset pattern.
4. WHEN the rename dialog opens, THE rename dialog SHALL pre-fill the mask input with the persisted default rename pattern.
5. THE Settings_Page SHALL display the currently persisted default rename pattern.

### Requirement 8: Preview Before Renaming Setting

**User Story:** As a user, I want to control whether the rename dialog always shows a preview step, so that I can skip it when I am confident in my pattern.

#### Acceptance Criteria

1. WHEN the user toggles the "Preview before renaming" switch, THE RenamingSettingsNotifier SHALL persist the boolean value to `shared_preferences` using a versioned Preference_Key.
2. WHEN the application starts, THE RenamingSettingsNotifier SHALL load the persisted "Preview before renaming" value from `shared_preferences`.
3. IF the "Preview before renaming" Preference_Key is missing or corrupted, THEN THE RenamingSettingsNotifier SHALL default to `true`.
4. WHILE the "Preview before renaming" setting is enabled, WHEN the user opens the rename dialog, THE rename dialog SHALL require the user to view the preview before executing the rename.
5. WHILE the "Preview before renaming" setting is disabled, WHEN the user opens the rename dialog, THE rename dialog SHALL allow direct execution without a mandatory preview step.

### Requirement 9: Settings Take Effect Immediately

**User Story:** As a user, I want settings changes to take effect immediately without restarting the app, so that my workflow is not interrupted.

#### Acceptance Criteria

1. WHEN any setting value changes, THE corresponding StateNotifier SHALL emit the new state to all active listeners immediately.
2. THE Settings_Page SHALL reflect updated setting values without requiring navigation away from and back to the page.
3. THE TagLibWriterService SHALL read the current setting values at the time of each write operation rather than caching values at startup.

### Requirement 10: Settings Page Performance

**User Story:** As a user, I want the Settings page to load quickly, so that adjusting preferences does not feel sluggish.

#### Acceptance Criteria

1. THE Settings_Page SHALL load and display all setting values within 100 milliseconds.
2. THE GeneralSettingsNotifier, TagWritingSettingsNotifier, and RenamingSettingsNotifier SHALL load persisted values asynchronously without blocking the UI thread.
