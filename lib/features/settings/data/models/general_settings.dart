/// Theme mode offered in Settings.
enum AppThemeMode { system, light, dark }

/// Persisted general application settings.
class GeneralSettings {
  const GeneralSettings({
    this.reopenLastFolder = false,
    this.fileCountThreshold = 500,
    this.backupEnabled = true,
    this.themeMode = AppThemeMode.system,
  });

  /// Whether to automatically reopen the last loaded folder on startup.
  final bool reopenLastFolder;

  /// The file count at which the "Large Directory" warning dialog is shown.
  /// Must be between 50 and 10000.
  final int fileCountThreshold;

  /// Whether a `.bak` copy is created before writing tags.
  final bool backupEnabled;

  /// Application theme mode.
  final AppThemeMode themeMode;

  /// Creates a copy with updated fields.
  GeneralSettings copyWith({
    bool? reopenLastFolder,
    int? fileCountThreshold,
    bool? backupEnabled,
    AppThemeMode? themeMode,
  }) {
    return GeneralSettings(
      reopenLastFolder: reopenLastFolder ?? this.reopenLastFolder,
      fileCountThreshold: fileCountThreshold ?? this.fileCountThreshold,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
