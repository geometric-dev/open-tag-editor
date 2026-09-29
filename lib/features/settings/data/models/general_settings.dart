/// Theme mode offered in Settings.
enum AppThemeMode { system, light, dark }

/// Persisted general application settings.
class GeneralSettings {
  const GeneralSettings({
    this.reopenLastFolder = false,
    this.fileCountThreshold = 500,
    this.backupEnabled = true,
    this.preserveTimestamp = false,
    this.confirmBeforeSave = false,
    this.highContrast = false,
    this.uiScale = 1.0,
    this.themeMode = AppThemeMode.system,
  });

  /// Whether to automatically reopen the last loaded folder on startup.
  final bool reopenLastFolder;

  /// The file count at which the "Large Directory" warning dialog is shown.
  /// Must be between 50 and 10000.
  final int fileCountThreshold;

  /// Whether a `.bak` copy is created before writing tags.
  final bool backupEnabled;

  /// When true, original file modification time is restored after tag writes
  /// (Tag&Rename: “Don’t change file timestamp on saving tags”).
  final bool preserveTimestamp;

  /// When true, an explicit confirmation is required before tags are written
  /// to disk.
  ///
  /// Off by default: the save path is reached constantly (Ctrl+S, the
  /// toolbar, the tag panel, the unsaved-changes guard) and prompting on
  /// every one of those would be noise rather than safety. Turning it on is
  /// for users who prefer an explicit stop before files are modified.
  final bool confirmBeforeSave;

  /// When true, a high-contrast colour scheme is used.
  ///
  /// The default scheme is generated from a seed colour, which yields
  /// mid-tone borders and text-on-surface pairs that are hard to resolve on
  /// a poor display or with reduced contrast sensitivity.
  final bool highContrast;

  /// Interface text scale, as a multiplier.
  ///
  /// Applied through `MediaQuery.textScaler` rather than by editing font
  /// sizes, so it composes with the platform's own accessibility text scale
  /// instead of fighting it. Clamped to [minUiScale]..[maxUiScale].
  final double uiScale;

  static const minUiScale = 0.75;
  static const maxUiScale = 1.75;

  /// The scale factors offered in the settings UI.
  static const uiScaleOptions = <double>[0.75, 0.9, 1.0, 1.15, 1.3, 1.5];

  /// Returns [uiScale] clamped to the supported range.
  double get effectiveUiScale => uiScale.clamp(minUiScale, maxUiScale);

  /// Application theme mode.
  final AppThemeMode themeMode;

  /// Creates a copy with updated fields.
  GeneralSettings copyWith({
    bool? reopenLastFolder,
    int? fileCountThreshold,
    bool? backupEnabled,
    bool? preserveTimestamp,
    bool? confirmBeforeSave,
    bool? highContrast,
    double? uiScale,
    AppThemeMode? themeMode,
  }) {
    return GeneralSettings(
      reopenLastFolder: reopenLastFolder ?? this.reopenLastFolder,
      fileCountThreshold: fileCountThreshold ?? this.fileCountThreshold,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      preserveTimestamp: preserveTimestamp ?? this.preserveTimestamp,
      confirmBeforeSave: confirmBeforeSave ?? this.confirmBeforeSave,
      highContrast: highContrast ?? this.highContrast,
      uiScale: uiScale ?? this.uiScale,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
