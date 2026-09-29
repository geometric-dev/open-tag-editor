import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'features/settings/data/models/window_state.dart';
import 'features/settings/data/notifiers/window_state_notifier.dart';
import 'features/settings/data/providers/settings_providers.dart';
import 'features/settings/data/services/window_state_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Load persisted window state before showing the window.
  final savedState = await WindowStateService.load();
  final windowState = savedState ?? WindowState.defaults();

  // Apply geometry before the window is shown to prevent layout jump.
  await _applyWindowGeometry(windowState, savedState != null);

  runApp(
    ProviderScope(
      overrides: [
        windowStateProvider.overrideWith(
          (_) => WindowStateNotifier(windowState),
        ),
      ],
      child: const OpenTagEditorApp(),
    ),
  );

  // Show the window after the app is built.
  await windowManager.show();
  await windowManager.focus();
}

/// Applies the window geometry, clamping to display bounds and handling
/// off-screen positions.
Future<void> _applyWindowGeometry(WindowState state, bool hasSavedState) async {
  try {
    // Hide window during geometry setup to prevent flash.
    await windowManager.hide();

    // Get primary display bounds for validation.
    final displays = PlatformDispatcher.instance.displays;
    final primaryDisplay = displays.isNotEmpty ? displays.first : null;

    var width = state.windowWidth.toDouble();
    var height = state.windowHeight.toDouble();
    var x = state.windowX.toDouble();
    var y = state.windowY.toDouble();

    if (primaryDisplay != null) {
      final displayWidth =
          primaryDisplay.size.width / primaryDisplay.devicePixelRatio;
      final displayHeight =
          primaryDisplay.size.height / primaryDisplay.devicePixelRatio;

      // Clamp size to display bounds.
      width = width.clamp(400.0, displayWidth);
      height = height.clamp(300.0, displayHeight);

      if (hasSavedState) {
        // Check if the window is off-screen.
        final isOffScreen = _isPositionOffScreen(x, y, width, height, displays);

        if (isOffScreen) {
          // Center on primary display.
          x = (displayWidth - width) / 2;
          y = (displayHeight - height) / 2;
        }
      } else {
        // No saved state — center on primary display.
        x = (displayWidth - width) / 2;
        y = (displayHeight - height) / 2;
      }
    }

    await windowManager.setSize(Size(width, height));
    await windowManager.setPosition(Offset(x, y));
  } catch (_) {
    // Fall back to default window behaviour if anything fails.
    await windowManager.setSize(const Size(1280, 800));
    await windowManager.center();
  }
}

/// Returns true if the window position is entirely off-screen
/// (no connected display contains any portion of the window).
bool _isPositionOffScreen(
  double x,
  double y,
  double width,
  double height,
  Iterable<Display> displays,
) {
  if (displays.isEmpty) return false;

  for (final display in displays) {
    final dpr = display.devicePixelRatio;
    const displayLeft = 0.0; // Simplified — display offsets not available
    const displayTop = 0.0;
    final displayRight = display.size.width / dpr;
    final displayBottom = display.size.height / dpr;

    // Check if any part of the window overlaps this display.
    final windowRight = x + width;
    final windowBottom = y + height;

    if (x < displayRight &&
        windowRight > displayLeft &&
        y < displayBottom &&
        windowBottom > displayTop) {
      return false; // Window overlaps this display
    }
  }

  return true; // No display contains any part of the window
}
