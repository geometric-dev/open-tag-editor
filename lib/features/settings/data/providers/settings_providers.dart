import 'package:flutter_riverpod/legacy.dart';

import '../models/general_settings.dart';
import '../models/renaming_settings.dart';
import '../models/tag_writing_settings.dart';
import '../models/window_state.dart';
import '../notifiers/general_settings_notifier.dart';
import '../notifiers/renaming_settings_notifier.dart';
import '../notifiers/tag_writing_settings_notifier.dart';
import '../notifiers/window_state_notifier.dart';

/// Provider for general settings.
final generalSettingsProvider =
    StateNotifierProvider<GeneralSettingsNotifier, GeneralSettings>((ref) {
  return GeneralSettingsNotifier();
});

/// Provider for tag-writing settings.
final tagWritingSettingsProvider =
    StateNotifierProvider<TagWritingSettingsNotifier, TagWritingSettings>(
        (ref) {
  return TagWritingSettingsNotifier();
});

/// Provider for renaming settings.
final renamingSettingsProvider =
    StateNotifierProvider<RenamingSettingsNotifier, RenamingSettings>((ref) {
  return RenamingSettingsNotifier();
});

/// Provider for window state (geometry, tag panel, last folder).
///
/// The initial state is overridden in main.dart with the persisted state
/// loaded before runApp. The default here is a fallback.
final windowStateProvider =
    StateNotifierProvider<WindowStateNotifier, WindowState>((ref) {
  return WindowStateNotifier(WindowState.defaults());
});
