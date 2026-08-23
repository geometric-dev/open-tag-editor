import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/general_settings.dart';

/// Manages general application settings with shared_preferences persistence.
class GeneralSettingsNotifier extends StateNotifier<GeneralSettings> {
  GeneralSettingsNotifier() : super(const GeneralSettings());

  static const _keyReopenLastFolder = 'settings_v1_general_reopen_last_folder';
  static const _keyFileCountThreshold =
      'settings_v1_general_file_count_threshold';
  static const _keyBackupEnabled = 'settings_v1_general_backup_enabled';
  static const _keyThemeMode = 'settings_v1_general_theme_mode';

  /// Loads settings from SharedPreferences.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = GeneralSettings(
        reopenLastFolder: prefs.getBool(_keyReopenLastFolder) ?? false,
        fileCountThreshold: prefs.getInt(_keyFileCountThreshold) ?? 500,
        backupEnabled: prefs.getBool(_keyBackupEnabled) ?? true,
        themeMode: _parseThemeMode(prefs.getString(_keyThemeMode)),
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

  /// Updates whether a `.bak` copy is created before writing tags.
  void setBackupEnabled(bool value) {
    state = state.copyWith(backupEnabled: value);
    _persist();
  }

  /// Updates the application theme mode.
  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
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
      await prefs.setBool(_keyBackupEnabled, state.backupEnabled);
      await prefs.setString(_keyThemeMode, state.themeMode.name);
    } catch (_) {
      // Best-effort persistence
    }
  }

  static AppThemeMode _parseThemeMode(String? value) {
    for (final mode in AppThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return AppThemeMode.system;
  }
}
