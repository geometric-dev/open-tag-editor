import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the recursive loading toggle state.
final recursiveLoadingProvider =
    StateNotifierProvider<RecursiveLoadingNotifier, bool>((ref) {
      return RecursiveLoadingNotifier();
    });

/// Manages the recursive folder loading toggle with persistence.
class RecursiveLoadingNotifier extends StateNotifier<bool> {
  RecursiveLoadingNotifier() : super(true);

  static const _prefsKey = 'recursive_loading_enabled';

  /// Loads persisted state from SharedPreferences.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_prefsKey);
      if (value != null) {
        state = value;
      }
    } catch (_) {
      // On error, keep default (true)
    }
  }

  /// Toggles the recursive loading state.
  void toggle() {
    state = !state;
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, state);
    } catch (_) {
      // Best-effort persistence
    }
  }
}
