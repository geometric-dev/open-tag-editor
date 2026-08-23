import 'package:flutter_riverpod/legacy.dart';

import '../models/window_state.dart';
import '../services/window_state_service.dart';

/// Manages the runtime window state and triggers persistence on changes.
class WindowStateNotifier extends StateNotifier<WindowState> {
  WindowStateNotifier(super.initial);

  /// Updates the window geometry. Called on window close.
  void updateGeometry(int width, int height, int x, int y) {
    state = state.copyWith(
      windowWidth: width,
      windowHeight: height,
      windowX: x,
      windowY: y,
    );
    WindowStateService.save(state);
  }

  /// Sets whether the tag panel is open or closed.
  void setTagPanelOpen(bool open) {
    if (state.isTagPanelOpen == open) return;
    state = state.copyWith(isTagPanelOpen: open);
    WindowStateService.save(state);
  }

  /// Sets the tag panel width. Called when the user finishes dragging
  /// the splitter.
  void setTagPanelWidth(double width) {
    final clamped = width.clamp(
      WindowState.minTagPanelWidth,
      state.windowWidth * WindowState.maxTagPanelWidthFraction,
    );
    state = state.copyWith(tagPanelWidth: clamped);
    WindowStateService.save(state);
  }

  /// Sets the error panel height. Called while the user drags the splitter.
  void setErrorPanelHeight(double height) {
    final clamped = height.clamp(
      WindowState.minErrorPanelHeight,
      state.windowHeight * 0.6,
    );
    if (state.errorPanelHeight == clamped) return;
    state = state.copyWith(errorPanelHeight: clamped);
    WindowStateService.save(state);
  }

  /// Sets the last loaded folder path.
  void setLastFolderPath(String? path) {
    state = state.copyWith(lastFolderPath: () => path);
    WindowStateService.save(state);
  }
}
