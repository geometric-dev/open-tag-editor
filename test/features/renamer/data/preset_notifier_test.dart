import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/renamer/data/models/mask_preset.dart';
import 'package:open_tag_editor/features/renamer/data/preset_notifier.dart';
import 'package:open_tag_editor/features/renamer/data/preset_storage.dart';

/// In-memory storage for testing.
class FakePresetStorage extends PresetStorage {
  List<MaskPreset> stored = [];
  String? lastUsed;

  @override
  Future<List<MaskPreset>> load() async => stored;

  @override
  Future<void> save(List<MaskPreset> presets) async {
    stored = presets.where((p) => !p.isBuiltIn).toList();
  }

  @override
  Future<String?> loadLastUsed() async => lastUsed;

  @override
  Future<void> saveLastUsed(String name) async {
    lastUsed = name;
  }
}

void main() {
  group('PresetNotifier.delete', () {
    late FakePresetStorage storage;
    late PresetNotifier notifier;

    setUp(() async {
      storage = FakePresetStorage();
      storage.stored = [
        const MaskPreset(name: 'User Preset 1', pattern: '%title'),
        const MaskPreset(name: 'User Preset 2', pattern: '%artist'),
      ];
      notifier = PresetNotifier(storage: storage);
      // Allow async _loadUserPresets to complete.
      await Future<void>.delayed(Duration.zero);
    });

    test('removes user preset at valid index', () async {
      // 5 built-in + 2 user = 7 total; user presets start at index 5.
      final initialLength = notifier.state.length;
      expect(initialLength, 7);

      await notifier.delete(5); // Remove 'User Preset 1'
      expect(notifier.state.length, 6);
      expect(notifier.state.any((p) => p.name == 'User Preset 1'), isFalse);
    });

    test('persists after deletion', () async {
      await notifier.delete(5);
      // Storage should only contain the remaining user preset.
      expect(storage.stored.length, 1);
      expect(storage.stored.first.name, 'User Preset 2');
    });

    test('no-op for negative index', () async {
      final before = notifier.state.length;
      await notifier.delete(-1);
      expect(notifier.state.length, before);
    });

    test('no-op for index >= length', () async {
      final before = notifier.state.length;
      await notifier.delete(100);
      expect(notifier.state.length, before);
    });

    test('no-op for built-in preset index', () async {
      final before = notifier.state.length;
      await notifier.delete(0); // First built-in preset
      expect(notifier.state.length, before);
    });
  });

  group('PresetNotifier last used', () {
    late FakePresetStorage storage;
    late PresetNotifier notifier;

    setUp(() async {
      storage = FakePresetStorage();
      notifier = PresetNotifier(storage: storage);
      await Future<void>.delayed(Duration.zero);
    });

    test('starts with no remembered preset', () {
      expect(notifier.lastUsedName, isNull);
      expect(notifier.lastUsedIndex, isNull);
    });

    test('markUsed records the name and resolves to its index', () {
      notifier.markUsed('Track - Title');

      expect(notifier.lastUsedName, 'Track - Title');
      expect(notifier.lastUsedIndex, 1); // second built-in
      expect(storage.lastUsed, 'Track - Title');
    });

    test('restores the remembered preset on a fresh notifier', () async {
      storage.lastUsed = 'Album / Disc-Track - Title';
      final reopened = PresetNotifier(storage: storage);
      await Future<void>.delayed(Duration.zero);

      expect(reopened.lastUsedIndex, 4);
    });

    test(
      'lastUsedIndex is null when the remembered preset was deleted',
      () async {
        storage.lastUsed = 'User Preset 1';
        storage.stored = [
          const MaskPreset(name: 'User Preset 1', pattern: '%title'),
        ];
        final withPreset = PresetNotifier(storage: storage);
        await Future<void>.delayed(Duration.zero);
        expect(withPreset.lastUsedIndex, isNotNull);

        await withPreset.delete(withPreset.lastUsedIndex!);

        // Name still remembered, but it no longer resolves to a live preset.
        expect(withPreset.lastUsedIndex, isNull);
      },
    );

    test('survives preset reordering by name, not index', () async {
      storage.stored = [
        const MaskPreset(name: 'A', pattern: '%title'),
        const MaskPreset(name: 'B', pattern: '%artist'),
      ];
      storage.lastUsed = 'B';
      final notifier2 = PresetNotifier(storage: storage);
      await Future<void>.delayed(Duration.zero);
      expect(notifier2.lastUsedIndex, 6); // 5 built-in + index 1

      // Adding a new preset shifts nothing before it, but deleting 'A' does.
      await notifier2.delete(5); // remove 'A'
      expect(notifier2.lastUsedName, 'B');
      expect(notifier2.lastUsedIndex, 5); // 'B' shifted down by one
    });
  });
}
