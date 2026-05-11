import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/mask_preset.dart';
import 'preset_storage.dart';

/// Manages mask preset persistence and selection.
class PresetNotifier extends StateNotifier<List<MaskPreset>> {
  PresetNotifier({PresetStorage? storage})
      : _storage = storage ?? PresetStorage(),
        super(_defaultPresets) {
    _loadUserPresets();
  }

  final PresetStorage _storage;

  /// Built-in default presets that cannot be deleted.
  static const List<MaskPreset> _defaultPresets = [
    MaskPreset(
      name: 'Artist - Title',
      pattern: '%artist - %title',
      isBuiltIn: true,
    ),
    MaskPreset(
      name: 'Track - Title',
      pattern: '%track - %title',
      isBuiltIn: true,
    ),
    MaskPreset(
      name: 'Artist - Album / Track - Title',
      pattern: '%artist - %album/%track - %title',
      isBuiltIn: true,
    ),
    MaskPreset(
      name: 'Track Artist - Title',
      pattern: '%track %artist - %title',
      isBuiltIn: true,
    ),
    MaskPreset(
      name: 'Album / Disc-Track - Title',
      pattern: '%album/%disc-%track - %title',
      isBuiltIn: true,
    ),
  ];

  Future<void> _loadUserPresets() async {
    final userPresets = await _storage.load();
    state = [..._defaultPresets, ...userPresets];
  }

  /// Saves a new preset with the given [name] and [pattern].
  Future<void> save(String name, String pattern) async {
    final preset = MaskPreset(name: name, pattern: pattern);
    state = [...state, preset];
    await _storage.save(state);
  }

  /// Deletes a user-created preset by [name].
  /// Built-in presets cannot be deleted.
  Future<void> delete(String name) async {
    if (isBuiltIn(name)) return;
    state = state.where((p) => p.name != name).toList();
    await _storage.save(state);
  }

  /// Returns true if the preset with [name] is a built-in default.
  bool isBuiltIn(String name) {
    return state.any((p) => p.name == name && p.isBuiltIn);
  }
}
