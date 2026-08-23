import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/renaming_settings.dart';

/// Manages file-renaming settings with shared_preferences persistence.
class RenamingSettingsNotifier extends StateNotifier<RenamingSettings> {
  RenamingSettingsNotifier() : super(const RenamingSettings());

  static const _keyDefaultPattern = 'settings_v1_renaming_default_pattern';
  static const _keyPreviewBeforeRenaming =
      'settings_v1_renaming_preview_before_renaming';

  /// Loads settings from SharedPreferences.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = RenamingSettings(
        defaultPattern:
            prefs.getString(_keyDefaultPattern) ?? '%artist% - %title%',
        previewBeforeRenaming: prefs.getBool(_keyPreviewBeforeRenaming) ?? true,
      );
    } catch (_) {
      // Keep defaults on error
    }
  }

  /// Updates the default rename pattern.
  void setDefaultPattern(String pattern) {
    state = state.copyWith(defaultPattern: pattern);
    _persist();
  }

  /// Updates the preview-before-renaming preference.
  void setPreviewBeforeRenaming(bool value) {
    state = state.copyWith(previewBeforeRenaming: value);
    _persist();
  }

  /// Resets all renaming settings to their factory defaults and persists.
  void resetToDefaults() {
    state = const RenamingSettings();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDefaultPattern, state.defaultPattern);
      await prefs.setBool(
        _keyPreviewBeforeRenaming,
        state.previewBeforeRenaming,
      );
    } catch (_) {
      // Best-effort persistence
    }
  }
}
