import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/general_settings.dart';

/// Manages general application settings with shared_preferences persistence.
class GeneralSettingsNotifier extends StateNotifier<GeneralSettings> {
  GeneralSettingsNotifier() : super(const GeneralSettings());

  static const _keyReopenLastFolder =
      'settings_v1_general_reopen_last_folder';
  static const _keyFileCountThreshold =
      'settings_v1_general_file_count_threshold';

  /// Loads settings from SharedPreferences.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = GeneralSettings(
        reopenLastFolder:
            prefs.getBool(_keyReopenLastFolder) ?? false,
        fileCountThreshold:
            prefs.getInt(_keyFileCountThreshold) ?? 500,
      );
    } catch (_) {
      // Keep defaults on error
    }
  }

  /// Updates the reopen-last-folder preference.
  void setReopenLastFolder(bool value) {
    state = state.copyWith(reopenLastFolder: value);
    _persist();
  }

  /// Updates the file-count threshold (clamped to 50–10000).
  void setFileCountThreshold(int value) {
    state = state.copyWith(fileCountThreshold: value.clamp(50, 10000));
    _persist();
  }

  /// Resets all general settings to their factory defaults and persists.
  void resetToDefaults() {
    state = const GeneralSettings();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyReopenLastFolder, state.reopenLastFolder);
      await prefs.setInt(_keyFileCountThreshold, state.fileCountThreshold);
    } catch (_) {
      // Best-effort persistence
    }
  }
}
