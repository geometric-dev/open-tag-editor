import 'package:shared_preferences/shared_preferences.dart';

import '../models/window_state.dart';

/// Service responsible for reading and writing window state to
/// persistent storage via shared_preferences.
///
/// All operations are static and fire-and-forget (async, non-blocking).
/// Corrupted or missing data is handled gracefully — load returns null.
class WindowStateService {
  WindowStateService._();

  static const _keyWidth = 'window_state_width';
  static const _keyHeight = 'window_state_height';
  static const _keyX = 'window_state_x';
  static const _keyY = 'window_state_y';
  static const _keyTagPanelOpen = 'window_state_tag_panel_open';
  static const _keyTagPanelWidth = 'window_state_tag_panel_width';
  static const _keyLastFolder = 'window_state_last_folder';

  /// Loads persisted window state. Returns null if no state is saved
  /// or if the persisted data is corrupted/unreadable.
  static Future<WindowState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final width = prefs.getInt(_keyWidth);
      final height = prefs.getInt(_keyHeight);
      final x = prefs.getInt(_keyX);
      final y = prefs.getInt(_keyY);

      // If any geometry key is missing, treat as no saved state
      if (width == null || height == null || x == null || y == null) {
        return null;
      }

      // Validate geometry values are positive
      if (width <= 0 || height <= 0) {
        return null;
      }

      final isTagPanelOpen = prefs.getBool(_keyTagPanelOpen) ?? false;
      final tagPanelWidth = prefs.getDouble(_keyTagPanelWidth) ?? 380.0;
      final lastFolderPath = prefs.getString(_keyLastFolder);

      // Clamp tag panel width to minimum (upper bound applied at runtime)
      final clampedWidth = tagPanelWidth < WindowState.minTagPanelWidth
          ? WindowState.minTagPanelWidth
          : tagPanelWidth;

      return WindowState(
        windowWidth: width,
        windowHeight: height,
        windowX: x,
        windowY: y,
        isTagPanelOpen: isTagPanelOpen,
        tagPanelWidth: clampedWidth,
        lastFolderPath: lastFolderPath,
      );
    } catch (_) {
      // Corrupted or unreadable data — return null for default fallback
      return null;
    }
  }

  /// Persists the given window state. Fire-and-forget (async, non-blocking).
  static Future<void> save(WindowState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyWidth, state.windowWidth);
      await prefs.setInt(_keyHeight, state.windowHeight);
      await prefs.setInt(_keyX, state.windowX);
      await prefs.setInt(_keyY, state.windowY);
      await prefs.setBool(_keyTagPanelOpen, state.isTagPanelOpen);
      await prefs.setDouble(_keyTagPanelWidth, state.tagPanelWidth);
      if (state.lastFolderPath != null) {
        await prefs.setString(_keyLastFolder, state.lastFolderPath!);
      } else {
        await prefs.remove(_keyLastFolder);
      }
    } catch (_) {
      // Best-effort persistence — swallow errors
    }
  }

  /// Clears all persisted window state.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyWidth);
      await prefs.remove(_keyHeight);
      await prefs.remove(_keyX);
      await prefs.remove(_keyY);
      await prefs.remove(_keyTagPanelOpen);
      await prefs.remove(_keyTagPanelWidth);
      await prefs.remove(_keyLastFolder);
    } catch (_) {
      // Best-effort
    }
  }
}
