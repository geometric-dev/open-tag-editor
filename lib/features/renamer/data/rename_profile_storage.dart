import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/rename_profile.dart';

/// Handles persistence for rename profiles using SharedPreferences.
class RenameProfileStorage {
  static const String _key = 'rename_profiles_v1';

  /// Loads saved profiles from storage.
  ///
  /// Returns null when nothing has ever been saved (so the caller can seed
  /// defaults), or the stored list (which may be empty) once the user has
  /// saved — even an empty list is a deliberate choice to have no profiles.
  Future<List<RenameProfile>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return null;
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => RenameProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves profiles to storage.
  Future<void> save(List<RenameProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
