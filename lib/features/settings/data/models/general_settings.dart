/// Persisted general application settings.
class GeneralSettings {
  const GeneralSettings({
    this.reopenLastFolder = false,
    this.fileCountThreshold = 500,
  });

  /// Whether to automatically reopen the last loaded folder on startup.
  final bool reopenLastFolder;

  /// The file count at which the "Large Directory" warning dialog is shown.
  /// Must be between 50 and 10000.
  final int fileCountThreshold;

  /// Creates a copy with updated fields.
  GeneralSettings copyWith({
    bool? reopenLastFolder,
    int? fileCountThreshold,
  }) {
    return GeneralSettings(
      reopenLastFolder: reopenLastFolder ?? this.reopenLastFolder,
      fileCountThreshold: fileCountThreshold ?? this.fileCountThreshold,
    );
  }
}
