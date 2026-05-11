import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the recent folders list.
final recentFoldersProvider =
    StateNotifierProvider<RecentFoldersNotifier, List<String>>((ref) {
  return RecentFoldersNotifier();
});

/// Manages a bounded list of recently loaded folder paths (max 10).
///
/// Persists to SharedPreferences for cross-session access.
class RecentFoldersNotifier extends StateNotifier<List<String>> {
  RecentFoldersNotifier() : super([]);

  static const _prefsKey = 'recent_folders_v1';
  static const _maxEntries = 10;

  /// Loads persisted recent folders from SharedPreferences.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final list = (jsonDecode(json) as List).cast<String>();
        state = list;
      }
    } catch (_) {
      // On error, keep empty list
    }
  }

  /// Adds a folder path to the front of the list.
  ///
  /// Deduplicates (moves existing entry to front) and caps at [_maxEntries].
  void addFolder(String path) {
    final updated = [path, ...state.where((p) => p != path)];
    state = updated.length > _maxEntries
        ? updated.sublist(0, _maxEntries)
        : updated;
    _persist();
  }

  /// Removes a folder from the list.
  void removeFolder(String path) {
    state = state.where((p) => p != path).toList();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state));
    } catch (_) {
      // Best-effort persistence
    }
  }
}
