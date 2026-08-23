import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the folder panel visibility state.
final folderPanelStateProvider =
    StateNotifierProvider<FolderPanelStateNotifier, bool>((ref) {
  return FolderPanelStateNotifier();
});

/// Manages folder panel visibility with SharedPreferences persistence.
///
/// The state is a boolean: `true` means the panel is visible (expanded),
/// `false` means it is collapsed (hidden). Defaults to `false` when no
/// persisted state exists.
class FolderPanelStateNotifier extends StateNotifier<bool> {
  FolderPanelStateNotifier() : super(false);

  static const _prefsKey = 'folder_panel_visible_v1';

  /// Loads persisted visibility state from SharedPreferences.
  ///
  /// Defaults to `false` (collapsed) if no value is stored or on error.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visible = prefs.getBool(_prefsKey);
      if (visible != null) {
        state = visible;
      }
    } catch (_) {
      // Best-effort: keep default (false) on error.
    }
  }

  /// Toggles visibility and persists the new state.
  void toggle() {
    state = !state;
    _persist();
  }

  /// Sets visibility explicitly and persists.
  void setVisible(bool visible) {
    state = visible;
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, state);
    } catch (_) {
      // Best-effort persistence.
    }
  }
}
