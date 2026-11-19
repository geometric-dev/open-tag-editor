import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/renamer/data/models/rename_profile.dart';
import 'package:open_tag_editor/features/renamer/data/rename_profile_notifier.dart';
import 'package:open_tag_editor/features/renamer/data/rename_profile_storage.dart';

/// In-memory storage for testing.
class FakeProfileStorage extends RenameProfileStorage {
  List<RenameProfile>? stored;
  int saveCount = 0;

  @override
  Future<List<RenameProfile>?> load() async => stored;

  @override
  Future<void> save(List<RenameProfile> profiles) async {
    stored = List.of(profiles);
    saveCount++;
  }
}

void main() {
  group('RenameProfileNotifier', () {
    late FakeProfileStorage storage;
    late RenameProfileNotifier notifier;

    setUp(() async {
      storage = FakeProfileStorage();
      notifier = RenameProfileNotifier(storage: storage);
      await Future<void>.delayed(Duration.zero);
    });

    test('seeds built-in profiles when nothing was ever saved', () {
      expect(notifier.state, isNotEmpty);
      // The first built-in is the VA/OST/Soundtrack profile (multi-group).
      expect(notifier.state.first.name, contains('Various Artists'));
      expect(notifier.state.first.conditionGroups.length, 3);
      expect(notifier.state.last.isCatchAll, isTrue);
    });

    test('respects an explicitly empty saved list', () async {
      storage.stored = [];
      final n = RenameProfileNotifier(storage: storage);
      await Future<void>.delayed(Duration.zero);
      expect(n.state, isEmpty);
    });

    test('add appends and persists', () async {
      await notifier.add(
        const RenameProfile(name: 'OST', pattern: '%album/%track'),
      );
      expect(notifier.state.last.name, 'OST');
      expect(storage.stored?.last.name, 'OST');
    });

    test('update replaces at index', () async {
      final before = notifier.state.first;
      await notifier.update(
        0,
        before.copyWith(name: 'Various Artists (edited)'),
      );
      expect(notifier.state.first.name, 'Various Artists (edited)');
    });

    test('delete removes at index', () async {
      final len = notifier.state.length;
      await notifier.delete(0);
      expect(notifier.state.length, len - 1);
    });

    test('moveUp / moveDown reorder and persist', () async {
      final firstName = notifier.state[1].name;
      await notifier.moveUp(1);
      expect(notifier.state[0].name, firstName);

      await notifier.moveDown(0);
      expect(notifier.state[1].name, firstName);
    });

    test('moveUp at top is a no-op', () async {
      final before = notifier.state.map((p) => p.name).toList();
      await notifier.moveUp(0);
      expect(notifier.state.map((p) => p.name).toList(), before);
    });

    test('out-of-range update/delete are no-ops', () async {
      final len = notifier.state.length;
      await notifier.update(99, const RenameProfile(name: 'x', pattern: 'y'));
      await notifier.delete(99);
      expect(notifier.state.length, len);
    });
  });
}
