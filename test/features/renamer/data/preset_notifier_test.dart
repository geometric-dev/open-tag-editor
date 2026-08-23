import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/renamer/data/models/mask_preset.dart';
import 'package:open_tag_editor/features/renamer/data/preset_notifier.dart';
import 'package:open_tag_editor/features/renamer/data/preset_storage.dart';

/// In-memory storage for testing.
class FakePresetStorage extends PresetStorage {
  List<MaskPreset> stored = [];

  @override
  Future<List<MaskPreset>> load() async => stored;

  @override
  Future<void> save(List<MaskPreset> presets) async {
    stored = presets.where((p) => !p.isBuiltIn).toList();
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
      expect(
        notifier.state.any((p) => p.name == 'User Preset 1'),
        isFalse,
      );
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
}
