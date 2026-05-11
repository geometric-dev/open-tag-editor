import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/mask_preset.dart';

/// Handles persistence for mask presets using SharedPreferences.
class PresetStorage {
  static const String _key = 'rename_presets';

  /// Loads saved presets from storage.
  Future<List<MaskPreset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null || json.isEmpty) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => MaskPreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves presets to storage (only user-created presets, not built-ins).
  Future<void> save(List<MaskPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final userPresets = presets.where((p) => !p.isBuiltIn).toList();
    final json = jsonEncode(userPresets.map((p) => p.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
