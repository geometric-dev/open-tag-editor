# Design Document: Settings Completeness

## Overview

This feature wires all existing Settings page UI controls to persisted state via `shared_preferences` and ensures each setting actively influences application behavior. Three new section-specific `StateNotifier` providers are introduced — `GeneralSettingsNotifier`, `TagWritingSettingsNotifier`, and `RenamingSettingsNotifier` — following the established `LookupSettingsNotifier` pattern (versioned preference keys, `loadFromPrefs()`, `_persist()`, fallback defaults).

The tag-writing preferences (ID3v2 version, ID3v1 toggle, text encoding) are passed through to `TagLibWriterService` via a `TagWriteOptions` value object read at write-time, ensuring settings take effect immediately without restart.

### Key Design Decisions

1. **One notifier per section** — Mirrors the existing `LookupSettingsNotifier` pattern. Each notifier owns its preference keys, load logic, and persistence. This keeps state scoped and avoids a monolithic settings object.

2. **Callback-based consumption in services** — `TagLibWriterService` already uses a `bool Function()` callback for backup-enabled. The same pattern extends to tag-writing options: a `TagWriteOptions Function()` callback injected at construction time, evaluated at each write call. This guarantees settings take effect immediately.

3. **Immutable state models with `copyWith`** — Each notifier's state is an immutable class with named constructor defaults and a `copyWith` method, matching `LookupSettings`.

4. **Versioned preference keys** — Keys follow the pattern `settings_v1_{section}_{field}` to allow future migration without collision.

5. **Confirmation dialog as a gating widget** — The confirm-before-saving flow is implemented as a dialog that receives the pending write batch and either proceeds or aborts. The dialog is shown by the save action orchestrator, not by the writer service itself.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Settings Page (UI)                         │
│  ┌──────────┐  ┌──────────────────┐  ┌───────────────────────┐  │
│  │ General  │  │   Tag Writing    │  │      Renaming         │  │
│  │ Section  │  │    Section       │  │      Section          │  │
│  └────┬─────┘  └───────┬──────────┘  └──────────┬────────────┘  │
└───────┼─────────────────┼────────────────────────┼───────────────┘
        │                 │                        │
        ▼                 ▼                        ▼
┌───────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
│ GeneralSettings│ │TagWritingSettings    │ │RenamingSettings      │
│ Notifier      │ │Notifier              │ │Notifier              │
│               │ │                      │ │                      │
│ • confirmSave │ │ • id3v2Version       │ │ • defaultPattern     │
│               │ │ • writeId3v1         │ │ • previewBeforeRename│
│               │ │ • encoding           │ │                      │
└───────┬───────┘ └──────────┬───────────┘ └──────────┬───────────┘
        │                    │                        │
        │                    ▼                        │
        │         ┌──────────────────────┐            │
        │         │  TagWriteOptions     │            │
        │         │  (value object)      │            │
        │         └──────────┬───────────┘            │
        │                    │                        │
        ▼                    ▼                        ▼
┌───────────────────────────────────────────────────────────────┐
│                     shared_preferences                         │
└───────────────────────────────────────────────────────────────┘

        ┌────────────────────────────────────────┐
        │         Save Action Flow               │
        │                                        │
        │  User triggers save                    │
        │         │                              │
        │         ▼                              │
        │  confirmBeforeSaving == true?          │
        │    ├─ yes → Show ConfirmationDialog    │
        │    │         ├─ confirm → writeTags()  │
        │    │         └─ cancel  → abort        │
        │    └─ no  → writeTags() immediately    │
        │                                        │
        └────────────────────────────────────────┘

        ┌────────────────────────────────────────┐
        │      TagLibWriterService                │
        │                                        │
        │  writeTags(path, tags)                 │
        │    1. Read TagWriteOptions callback    │
        │    2. Set ID3v2 version via FFI        │
        │    3. Set encoding via FFI             │
        │    4. Write ID3v2 tags                 │
        │    5. If writeId3v1 → write ID3v1     │
        │    6. Save file                        │
        │                                        │
        └────────────────────────────────────────┘
```

### Data Flow

1. App starts → each notifier calls `loadFromPrefs()` asynchronously
2. Notifiers emit loaded state → Settings page renders current values
3. User changes a setting → notifier updates state + calls `_persist()`
4. `tagWriterProvider` injects a `TagWriteOptions Function()` callback that reads current `TagWritingSettingsNotifier` state
5. On save action: orchestrator checks `GeneralSettingsNotifier.confirmBeforeSaving` → shows dialog or proceeds directly
6. `TagLibWriterService.writeTags()` calls the options callback at invocation time → uses current ID3v2 version, encoding, and ID3v1 flag

## Components and Interfaces

### GeneralSettingsNotifier

```dart
/// Manages general application settings with shared_preferences persistence.
class GeneralSettingsNotifier extends StateNotifier<GeneralSettings> {
  GeneralSettingsNotifier() : super(const GeneralSettings());

  static const _keyConfirmBeforeSaving = 'settings_v1_general_confirm_before_saving';

  /// Loads settings from SharedPreferences.
  Future<void> loadFromPrefs() async;

  /// Updates the confirm-before-saving preference.
  void setConfirmBeforeSaving(bool value);
}
```

### TagWritingSettingsNotifier

```dart
/// Manages tag-writing settings with shared_preferences persistence.
class TagWritingSettingsNotifier extends StateNotifier<TagWritingSettings> {
  TagWritingSettingsNotifier() : super(const TagWritingSettings());

  static const _keyId3v2Version = 'settings_v1_tagwriting_id3v2_version';
  static const _keyWriteId3v1 = 'settings_v1_tagwriting_write_id3v1';
  static const _keyEncoding = 'settings_v1_tagwriting_encoding';

  /// Loads settings from SharedPreferences.
  Future<void> loadFromPrefs() async;

  /// Updates the default ID3v2 version.
  void setId3v2Version(Id3v2Version version);

  /// Updates the write-ID3v1 preference.
  void setWriteId3v1(bool value);

  /// Updates the default text encoding.
  void setEncoding(TagEncoding encoding);
}
```

### RenamingSettingsNotifier

```dart
/// Manages file-renaming settings with shared_preferences persistence.
class RenamingSettingsNotifier extends StateNotifier<RenamingSettings> {
  RenamingSettingsNotifier() : super(const RenamingSettings());

  static const _keyDefaultPattern = 'settings_v1_renaming_default_pattern';
  static const _keyPreviewBeforeRenaming = 'settings_v1_renaming_preview_before_renaming';

  /// Loads settings from SharedPreferences.
  Future<void> loadFromPrefs() async;

  /// Updates the default rename pattern.
  void setDefaultPattern(String pattern);

  /// Updates the preview-before-renaming preference.
  void setPreviewBeforeRenaming(bool value);
}
```

### TagWriteOptions

A value object passed to `TagLibWriterService` at write-time.

```dart
/// Options controlling how tags are written to audio files.
class TagWriteOptions {
  const TagWriteOptions({
    this.id3v2Version = Id3v2Version.v24,
    this.writeId3v1 = false,
    this.encoding = TagEncoding.utf8,
  });

  final Id3v2Version id3v2Version;
  final bool writeId3v1;
  final TagEncoding encoding;
}
```

### TagLibWriterService (extended interface)

The existing `writeTags` method signature remains unchanged. The writer reads options from its injected callback internally:

```dart
class TagLibWriterService implements TagWriterService {
  TagLibWriterService(
    this._bindings,
    this._backupManager,
    this._validator, {
    required TagWriteOptions Function() getWriteOptions,
  }) : _getWriteOptions = getWriteOptions;

  final TagWriteOptions Function() _getWriteOptions;

  @override
  Future<void> writeTags(String path, Map<String, String> tags) async {
    _assertFileExists(path);
    await _backupManager.createBackupIfEnabled(path);
    final options = _getWriteOptions();

    await _atomicWriteManager.writeAtomic(path, (tempPath) async {
      // ... open file, set ID3v2 version, set encoding, write properties
      // ... conditionally write ID3v1 block based on options.writeId3v1
    });

    await _validator.validate(path, tags);
  }
}
```

### ConfirmationDialog

```dart
/// A modal dialog that displays pending tag changes for user confirmation.
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.pendingChanges,
  });

  /// Map of file path → map of field name → new value.
  final Map<String, Map<String, String>> pendingChanges;
}
```

### Provider Definitions

```dart
/// Provider for general settings.
final generalSettingsProvider =
    StateNotifierProvider<GeneralSettingsNotifier, GeneralSettings>((ref) {
  return GeneralSettingsNotifier();
});

/// Provider for tag-writing settings.
final tagWritingSettingsProvider =
    StateNotifierProvider<TagWritingSettingsNotifier, TagWritingSettings>((ref) {
  return TagWritingSettingsNotifier();
});

/// Provider for renaming settings.
final renamingSettingsProvider =
    StateNotifierProvider<RenamingSettingsNotifier, RenamingSettings>((ref) {
  return RenamingSettingsNotifier();
});
```

The `tagWriterProvider` is updated to inject the write options callback:

```dart
final tagWriterProvider = Provider<TagWriterService>((ref) {
  if (NativeLibraryLoader.isAvailable) {
    final bindings = TagLibBindings(NativeLibraryLoader.load());
    final backupManager = BackupManager(
      isBackupEnabled: () => ref.read(backupEnabledProvider),
    );
    final reader = ref.read(tagReaderProvider);
    final validator = ValidationEngine(reader);
    return TagLibWriterService(
      bindings,
      backupManager,
      validator,
      getWriteOptions: () => TagWriteOptions(
        id3v2Version: ref.read(tagWritingSettingsProvider).id3v2Version,
        writeId3v1: ref.read(tagWritingSettingsProvider).writeId3v1,
        encoding: ref.read(tagWritingSettingsProvider).encoding,
      ),
    );
  }
  return DisabledWriterService();
});
```

## Data Models

### GeneralSettings

```dart
/// Persisted general application settings.
class GeneralSettings {
  const GeneralSettings({
    this.confirmBeforeSaving = true,
  });

  /// Whether to show a confirmation dialog before writing tag changes.
  final bool confirmBeforeSaving;

  GeneralSettings copyWith({bool? confirmBeforeSaving}) {
    return GeneralSettings(
      confirmBeforeSaving: confirmBeforeSaving ?? this.confirmBeforeSaving,
    );
  }
}
```

### TagWritingSettings

```dart
/// Persisted tag-writing settings.
class TagWritingSettings {
  const TagWritingSettings({
    this.id3v2Version = Id3v2Version.v24,
    this.writeId3v1 = false,
    this.encoding = TagEncoding.utf8,
  });

  /// The ID3v2 sub-version to write (2.3 or 2.4).
  final Id3v2Version id3v2Version;

  /// Whether to also write legacy ID3v1 tags.
  final bool writeId3v1;

  /// The text encoding for ID3v2 frames.
  final TagEncoding encoding;

  TagWritingSettings copyWith({
    Id3v2Version? id3v2Version,
    bool? writeId3v1,
    TagEncoding? encoding,
  }) {
    return TagWritingSettings(
      id3v2Version: id3v2Version ?? this.id3v2Version,
      writeId3v1: writeId3v1 ?? this.writeId3v1,
      encoding: encoding ?? this.encoding,
    );
  }
}
```

### RenamingSettings

```dart
/// Persisted file-renaming settings.
class RenamingSettings {
  const RenamingSettings({
    this.defaultPattern = '%artist% - %title%',
    this.previewBeforeRenaming = true,
  });

  /// The default mask pattern pre-filled in the rename dialog.
  final String defaultPattern;

  /// Whether the rename dialog requires preview before execution.
  final bool previewBeforeRenaming;

  RenamingSettings copyWith({
    String? defaultPattern,
    bool? previewBeforeRenaming,
  }) {
    return RenamingSettings(
      defaultPattern: defaultPattern ?? this.defaultPattern,
      previewBeforeRenaming: previewBeforeRenaming ?? this.previewBeforeRenaming,
    );
  }
}
```

### Id3v2Version

```dart
/// Supported ID3v2 sub-versions.
enum Id3v2Version {
  v23('ID3v2.3', 3),
  v24('ID3v2.4', 4);

  const Id3v2Version(this.displayName, this.numericVersion);

  final String displayName;
  final int numericVersion;
}
```

### TagEncoding

```dart
/// Supported text encodings for ID3v2 frames.
enum TagEncoding {
  utf8('UTF-8', 3),
  utf16('UTF-16', 1),
  latin1('Latin-1', 0);

  const TagEncoding(this.displayName, this.id3v2EncodingByte);

  final String displayName;

  /// The encoding byte value used in ID3v2 frame headers.
  final int id3v2EncodingByte;
}
```

### PendingTagChange (for confirmation dialog)

```dart
/// Represents a pending tag change for a single file.
class PendingTagChange {
  const PendingTagChange({
    required this.filePath,
    required this.fieldChanges,
  });

  /// The absolute path to the file being modified.
  final String filePath;

  /// Map of field name → new value for fields that changed.
  final Map<String, String> fieldChanges;
}
```

## Error Handling

### Preference Loading Errors

- **Missing key**: Each notifier catches exceptions from `SharedPreferences` and falls back to constructor defaults. No error is surfaced to the user.
- **Wrong type stored**: If `getString` returns null for an enum key (corrupted data), the notifier uses its default value. A `try/catch` around each `prefs.get*()` call ensures one corrupted key doesn't prevent loading other keys.
- **SharedPreferences unavailable**: If `SharedPreferences.getInstance()` throws (extremely rare), the notifier keeps its default state. The app remains functional with default settings.

### Preference Persistence Errors

- **Write failure**: `_persist()` is fire-and-forget with a `try/catch`. If persistence fails, the in-memory state is still correct for the current session. The next successful persist will overwrite.

### TagLibWriterService Errors

- **Invalid version/encoding combination**: ID3v2.3 does not support UTF-8 encoding (only Latin-1 and UTF-16). If the user selects v2.3 + UTF-8, the writer falls back to UTF-16 and logs a warning. This is handled in the FFI layer.
- **FFI call failure**: Existing error handling in `TagLibWriterService` (throwing `TagWriteException`) remains unchanged. The new options are applied before the existing write logic.

### Confirmation Dialog Errors

- **Empty change set**: If the pending changes map is empty (edge case), the dialog is not shown and the save is a no-op.
- **Dialog dismissed via back button/outside tap**: Treated as cancel — no write occurs.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: GeneralSettings persistence round-trip

*For any* boolean value assigned to `confirmBeforeSaving`, persisting the `GeneralSettings` state to `shared_preferences` and then loading it back via `loadFromPrefs()` SHALL produce a state with the same `confirmBeforeSaving` value.

**Validates: Requirements 1.1, 1.2**

### Property 2: TagWritingSettings persistence round-trip

*For any* combination of `Id3v2Version`, `writeId3v1` boolean, and `TagEncoding` values, persisting the `TagWritingSettings` state to `shared_preferences` and then loading it back via `loadFromPrefs()` SHALL produce a state with identical `id3v2Version`, `writeId3v1`, and `encoding` values.

**Validates: Requirements 3.1, 3.2, 5.1, 5.2, 6.1, 6.2**

### Property 3: RenamingSettings persistence round-trip

*For any* non-empty pattern string and boolean `previewBeforeRenaming` value, persisting the `RenamingSettings` state to `shared_preferences` and then loading it back via `loadFromPrefs()` SHALL produce a state with the same `defaultPattern` and `previewBeforeRenaming` values.

**Validates: Requirements 7.1, 7.2, 8.1, 8.2**

### Property 4: Confirmation dialog content completeness

*For any* non-empty set of `PendingTagChange` objects, the confirmation dialog's rendered content SHALL include every file path and every changed field name with its new value from the input set.

**Validates: Requirements 2.1**

## Testing Strategy

### Property-Based Tests (using `package:fast_check`)

Property-based tests validate the 4 correctness properties defined above. Each test runs a minimum of 100 iterations with randomly generated inputs.

**Test configuration:**
- Library: `package:fast_check` (Dart)
- Minimum iterations: 100 per property
- Tag format: `// Feature: settings-completeness, Property N: <property text>`

**Generators needed:**
- `generalSettingsGen`: Generates random `GeneralSettings` (random bool for confirmBeforeSaving)
- `tagWritingSettingsGen`: Generates random `TagWritingSettings` (random Id3v2Version, random bool, random TagEncoding)
- `renamingSettingsGen`: Generates random `RenamingSettings` (random non-empty string for pattern, random bool for preview)
- `pendingTagChangeListGen`: Generates random lists of `PendingTagChange` with random file paths and field maps

**Property test files:**
- `test/features/settings/data/general_settings_notifier_test.dart` — Property 1
- `test/features/settings/data/tag_writing_settings_notifier_test.dart` — Property 2
- `test/features/settings/data/renaming_settings_notifier_test.dart` — Property 3
- `test/features/settings/presentation/confirmation_dialog_test.dart` — Property 4

### Unit Tests (example-based)

- **Default fallbacks**: Each notifier loaded with missing/corrupted keys returns expected defaults (confirmBeforeSaving=true, id3v2Version=v24, writeId3v1=false, encoding=utf8, defaultPattern='%artist% - %title%', previewBeforeRenaming=true)
- **Enum parsing**: Invalid stored strings for version/encoding fall back to defaults
- **TagWriteOptions construction**: Verify the options callback reads current notifier state

### Integration Tests

- **TagLibWriterService + options**: Verify that changing tag-writing settings between writes results in different FFI parameters being used
- **Save action flow**: Verify confirm-before-saving gates the write operation correctly (dialog shown/skipped based on setting)
- **Rename dialog pre-fill**: Verify the rename dialog reads the default pattern from RenamingSettingsNotifier

### Widget Tests

- **Settings page rendering**: Each section displays current values from its notifier
- **Toggle interactions**: Toggling a switch updates the notifier and re-renders
- **Picker dialogs**: Version and encoding pickers update the notifier on selection
- **Confirmation dialog**: Displays all file paths and change summaries, confirm/cancel produce correct outcomes
