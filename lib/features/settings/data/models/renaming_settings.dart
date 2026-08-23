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

  /// Creates a copy with updated fields.
  RenamingSettings copyWith({
    String? defaultPattern,
    bool? previewBeforeRenaming,
  }) {
    return RenamingSettings(
      defaultPattern: defaultPattern ?? this.defaultPattern,
      previewBeforeRenaming:
          previewBeforeRenaming ?? this.previewBeforeRenaming,
    );
  }
}
