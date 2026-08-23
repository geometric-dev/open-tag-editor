import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/id3v2_version.dart';
import '../models/tag_encoding.dart';
import '../models/tag_writing_settings.dart';

/// Manages tag-writing settings with shared_preferences persistence.
class TagWritingSettingsNotifier extends StateNotifier<TagWritingSettings> {
  TagWritingSettingsNotifier() : super(const TagWritingSettings());

  static const _keyId3v2Version = 'settings_v1_tagwriting_id3v2_version';
  static const _keyWriteId3v1 = 'settings_v1_tagwriting_write_id3v1';
  static const _keyEncoding = 'settings_v1_tagwriting_encoding';

  /// Loads settings from SharedPreferences.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = TagWritingSettings(
        id3v2Version: _parseId3v2Version(prefs.getString(_keyId3v2Version)),
        writeId3v1: prefs.getBool(_keyWriteId3v1) ?? false,
        encoding: _parseEncoding(prefs.getString(_keyEncoding)),
      );
    } catch (_) {
      // Keep defaults on error
    }
  }

  /// Updates the default ID3v2 version.
  void setId3v2Version(Id3v2Version version) {
    state = state.copyWith(id3v2Version: version);
    _persist();
  }

  /// Updates the write-ID3v1 preference.
  void setWriteId3v1(bool value) {
    state = state.copyWith(writeId3v1: value);
    _persist();
  }

  /// Updates the default text encoding.
  void setEncoding(TagEncoding encoding) {
    state = state.copyWith(encoding: encoding);
    _persist();
  }

  /// Resets all tag-writing settings to their factory defaults and persists.
  void resetToDefaults() {
    state = const TagWritingSettings();
    _persist();
  }

  Id3v2Version _parseId3v2Version(String? value) {
    if (value == null) return Id3v2Version.v24;
    for (final version in Id3v2Version.values) {
      if (version.name == value) return version;
    }
    return Id3v2Version.v24;
  }

  TagEncoding _parseEncoding(String? value) {
    if (value == null) return TagEncoding.utf8;
    for (final encoding in TagEncoding.values) {
      if (encoding.name == value) return encoding;
    }
    return TagEncoding.utf8;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyId3v2Version, state.id3v2Version.name);
      await prefs.setBool(_keyWriteId3v1, state.writeId3v1);
      await prefs.setString(_keyEncoding, state.encoding.name);
    } catch (_) {
      // Best-effort persistence
    }
  }
}
