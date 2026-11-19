import 'package:flutter_riverpod/legacy.dart';

import 'models/rename_profile.dart';
import 'rename_profile_storage.dart';

/// Manages rename profiles: persistence, ordering, and lookup.
///
/// Profiles are evaluated top-to-bottom by the rename dialog, so order is
/// meaningful (most specific first). The notifier exposes helpers to add,
/// update, delete, and reorder profiles, persisting after each change.
class RenameProfileNotifier extends StateNotifier<List<RenameProfile>> {
  RenameProfileNotifier({RenameProfileStorage? storage})
    : _storage = storage ?? RenameProfileStorage(),
      super(_defaultProfiles) {
    _load();
  }

  final RenameProfileStorage _storage;

  /// Built-in starter profiles.
  ///
  /// These are ordinary profiles (not locked): the user can edit or delete
  /// them. They exist so the feature is useful on first run — Standard as a
  /// catch-all, plus a couple of common shapes. The catch-all must stay last
  /// so specific profiles above it win.
  static const List<RenameProfile> _defaultProfiles = [
    RenameProfile(
      name: 'Various Artists / OST / Soundtrack',
      pattern: '%album/%disc%track - %title',
      isBuiltIn: true,
      conditionGroups: [
        [
          ProfileCondition(
            field: 'albumArtist',
            operator: ProfileOperator.equals,
            value: 'Various Artists',
          ),
        ],
        [
          ProfileCondition(
            field: 'albumArtist',
            operator: ProfileOperator.equals,
            value: 'OST',
          ),
        ],
        [
          ProfileCondition(
            field: 'albumArtist',
            operator: ProfileOperator.equals,
            value: 'Soundtrack',
          ),
        ],
      ],
    ),
    RenameProfile(
      name: 'Multi-disc',
      pattern: '%artist - %album/%disc-%track - %title',
      isBuiltIn: true,
      conditionGroups: [
        [
          ProfileCondition(
            field: 'discCount',
            operator: ProfileOperator.greaterThan,
            value: '1',
          ),
        ],
      ],
    ),
    RenameProfile(
      name: 'Standard',
      pattern: '%artist - %album/%track - %title',
      isBuiltIn: true,
    ),
  ];

  Future<void> _load() async {
    final stored = await _storage.load();
    // null means nothing was ever saved → seed the built-in starter profiles.
    // An empty (non-null) list is a deliberate "no profiles" and is respected.
    state = stored ?? _defaultProfiles;
  }

  /// Adds [profile] and persists.
  Future<void> add(RenameProfile profile) async {
    state = [...state, profile];
    await _persist();
  }

  /// Replaces the profile at [index] with [profile].
  Future<void> update(int index, RenameProfile profile) async {
    if (index < 0 || index >= state.length) return;
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) profile else state[i],
    ];
    await _persist();
  }

  /// Removes the profile at [index].
  Future<void> delete(int index) async {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
    await _persist();
  }

  /// Moves the profile at [index] one position up (toward higher priority).
  Future<void> moveUp(int index) async {
    if (index <= 0 || index >= state.length) return;
    final list = [...state];
    final item = list.removeAt(index);
    list.insert(index - 1, item);
    state = list;
    await _persist();
  }

  /// Moves the profile at [index] one position down (toward lower priority).
  Future<void> moveDown(int index) async {
    if (index < 0 || index >= state.length - 1) return;
    final list = [...state];
    final item = list.removeAt(index);
    list.insert(index + 1, item);
    state = list;
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.save(state);
  }
}

/// Provider for rename profiles.
final renameProfileProvider =
    StateNotifierProvider<RenameProfileNotifier, List<RenameProfile>>((ref) {
      return RenameProfileNotifier();
    });
