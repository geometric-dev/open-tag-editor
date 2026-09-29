import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lookup_settings.dart';
import '../models/search_result.dart';

/// Provider for lookup settings.
final lookupSettingsProvider =
    StateNotifierProvider<LookupSettingsNotifier, LookupSettings>((ref) {
      return LookupSettingsNotifier();
    });

/// Manages lookup settings with SharedPreferences persistence.
class LookupSettingsNotifier extends StateNotifier<LookupSettings> {
  LookupSettingsNotifier() : super(const LookupSettings());

  static const _keyDiscogsToken = 'lookup_discogs_token';
  static const _keyFpcalcPath = 'lookup_fpcalc_path';
  static const _keyDefaultSource = 'lookup_default_source';
  static const _keyAutoFetchArt = 'lookup_auto_fetch_art';
  static const _keyPreservedFields = 'lookup_preserved_fields';

  /// Loads settings from SharedPreferences.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = LookupSettings(
        discogsToken: prefs.getString(_keyDiscogsToken) ?? '',
        fpcalcPath: prefs.getString(_keyFpcalcPath) ?? '',
        defaultSource: _parseSource(prefs.getString(_keyDefaultSource)),
        autoFetchCoverArt: prefs.getBool(_keyAutoFetchArt) ?? true,
        preservedFields: prefs.getStringList(_keyPreservedFields) == null
            ? LookupSettings.defaultPreservedFields
            : prefs.getStringList(_keyPreservedFields)!.toSet(),
      );
    } catch (e) {
      // Keep defaults on error — log for debugging
      assert(() {
        // ignore: avoid_print
        print('LookupSettingsNotifier.loadFromPrefs failed: $e');
        return true;
      }());
    }
  }

  /// Updates the Discogs token.
  void setDiscogsToken(String token) {
    state = state.copyWith(discogsToken: token);
    _persist();
  }

  /// Updates the fpcalc binary path.
  void setFpcalcPath(String path) {
    state = state.copyWith(fpcalcPath: path);
    _persist();
  }

  /// Updates the auto-fetch cover art setting.
  void setAutoFetchCoverArt(bool enabled) {
    state = state.copyWith(autoFetchCoverArt: enabled);
    _persist();
  }

  /// Replaces the whole preserved-field set.
  void setPreservedFields(Set<String> fields) {
    state = state.copyWith(preservedFields: fields);
    _persist();
  }

  /// Adds or removes a single preserved field.
  void togglePreservedField(String field, bool preserved) {
    final next = Set<String>.from(state.preservedFields);
    if (preserved) {
      next.add(field);
    } else {
      next.remove(field);
    }
    setPreservedFields(next);
  }

  /// Adds or removes every field in [preset].
  void togglePreset(PreservedFieldPreset preset, bool enabled) {
    final next = Set<String>.from(state.preservedFields);
    if (enabled) {
      next.addAll(preset.fields);
    } else {
      next.removeAll(preset.fields);
    }
    setPreservedFields(next);
  }

  /// Resets all lookup settings to their factory defaults and persists.
  void resetToDefaults() {
    state = const LookupSettings();
    _persist();
  }

  SearchSource _parseSource(String? value) {
    if (value == 'discogs') return SearchSource.discogs;
    return SearchSource.musicBrainz;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDiscogsToken, state.discogsToken);
      await prefs.setString(_keyFpcalcPath, state.fpcalcPath);
      await prefs.setString(_keyDefaultSource, state.defaultSource.name);
      await prefs.setBool(_keyAutoFetchArt, state.autoFetchCoverArt);
      // Sorted so the persisted value is stable, which keeps an unchanged
      // settings object from looking like a change after a reload.
      await prefs.setStringList(
        _keyPreservedFields,
        [...state.preservedFields]..sort(),
      );
    } catch (_) {
      // Best-effort persistence
    }
  }
}
