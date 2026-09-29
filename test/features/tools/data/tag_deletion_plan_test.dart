import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tools/data/tag_deletion_plan.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile file(
  String path, {
  Map<String, String> tags = const {},
  String extension = '.mp3',
  Map<String, String>? originalTags,
}) {
  return AudioFile(
    path: path,
    filename: path.split('/').last,
    extension: extension,
    fileSize: 1,
    tags: tags,
    originalTags: originalTags,
  );
}

void main() {
  group('inventoryFields', () {
    test('empty selection yields no fields', () {
      expect(inventoryFields(const []), isEmpty);
    });

    test('lists only fields that carry a value', () {
      final usage = inventoryFields([
        file('/a.mp3', tags: const {'title': 'T', 'artist': 'A'}),
      ]);

      expect(usage.map((u) => u.field), containsAll(['title', 'artist']));
      expect(usage.map((u) => u.field), isNot(contains('album')));
    });

    test('blank and whitespace-only values count as absent', () {
      final usage = inventoryFields([
        file('/a.mp3', tags: const {'title': '', 'artist': '   '}),
      ]);

      expect(usage, isEmpty);
    });

    test('counts distinct files, not occurrences, per field', () {
      final usage = inventoryFields([
        file('/a.mp3', tags: const {'artist': 'A; B'}),
      ]);

      expect(usage.single.presentCount, 1);
    });

    test('a field present on every file is universal', () {
      final usage = inventoryFields([
        file('/a.mp3', tags: const {'title': 'A'}),
        file('/b.mp3', tags: const {'title': 'B'}),
      ]).first;

      expect(usage.field, 'title');
      expect(usage.isUniversal, isTrue);
      expect(usage.isPartial, isFalse);
    });

    test('a field present on some files is marked partial', () {
      final usage = inventoryFields([
        file('/a.mp3', tags: const {'title': 'A', 'comment': 'c'}),
        file('/b.mp3', tags: const {'title': 'B'}),
        file('/c.mp3', tags: const {'title': 'C'}),
      ]).firstWhere((u) => u.field == 'comment');

      expect(usage.presentCount, 1);
      expect(usage.fileCount, 3);
      expect(usage.isPartial, isTrue);
      expect(usage.isUniversal, isFalse);
    });

    test('ordering is stable and known fields come first', () {
      final usage = inventoryFields([
        file('/a.mp3', tags: const {'ZZZ_CUSTOM': 'x', 'title': 'T'}),
      ]);

      expect(usage.first.field, 'title');
      expect(usage.last.field, 'ZZZ_CUSTOM');
    });

    test('labels fall back to the raw key for unmapped fields', () {
      final usage = inventoryFields([
        file('/a.mp3', tags: const {'MYSTERY': 'x'}),
      ]).single;

      expect(usage.label, 'MYSTERY');
    });

    test('labels use the enum display name for known fields', () {
      final usage = inventoryFields([
        file('/a.mp3', tags: const {'albumArtist': 'x'}),
      ]).single;

      expect(usage.label, 'Album Artist');
    });
  });

  group('planClear', () {
    test('no files yields the empty plan', () {
      expect(planClear(const [], null).isEmpty, isTrue);
    });

    test('null fields plans every managed field on each file', () {
      final plan = planClear([
        file('/a.mp3', tags: const {'title': 'T', 'artist': 'A'}),
        file('/b.mp3', tags: const {'title': 'U'}),
      ], null);

      expect(plan.affectedFileCount, 2);
      expect(plan.fieldCount, 3);
      expect(plan.fieldsToClearByPath['/a.mp3'], {'title', 'artist'});
      expect(plan.fieldsToClearByPath['/b.mp3'], {'title'});
    });

    test('a named field set only clears those fields', () {
      final plan = planClear(
        [
          file('/a.mp3', tags: const {'title': 'T', 'artist': 'A'}),
        ],
        {'artist'},
      );

      expect(plan.fieldCount, 1);
      expect(plan.fieldsToClearByPath['/a.mp3'], {'artist'});
    });

    test('files lacking the chosen fields are not counted as affected', () {
      final plan = planClear(
        [
          file('/a.mp3', tags: const {'title': 'T'}),
          file('/b.mp3', tags: const {'artist': 'A'}),
        ],
        {'artist'},
      );

      expect(plan.affectedFileCount, 1);
      expect(plan.fieldsToClearByPath.containsKey('/a.mp3'), isFalse);
    });

    test('a plan over only absent fields is empty', () {
      final plan = planClear(
        [
          file('/a.mp3', tags: const {'title': 'T'}),
        ],
        {'composer'},
      );

      expect(plan.isEmpty, isTrue);
    });

    test('captures previous tags per file for exact undo', () {
      final plan = planClear([
        file('/a.mp3', tags: const {'title': 'T', 'artist': 'A'}),
      ], null);

      expect(plan.previousTags['/a.mp3'], {'title': 'T', 'artist': 'A'});
    });

    test('previous tags are a copy, not a live view', () {
      final source = {'title': 'T'};
      final plan = planClear([file('/a.mp3', tags: source)], null);

      source['title'] = 'MUTATED';
      expect(plan.previousTags['/a.mp3']!['title'], 'T');
    });

    test('counts files that carry no tags at all', () {
      final plan = planClear([
        file('/a.mp3', tags: const {'title': 'T'}),
        file('/b.mp3'),
      ], null);

      expect(plan.filesWithoutTags, 1);
      expect(plan.fileCount, 2);
    });

    test('blank values are not planned for clearing', () {
      final plan = planClear([
        file('/a.mp3', tags: const {'title': '', 'artist': 'A'}),
      ], null);

      expect(plan.fieldCount, 1);
      expect(plan.fieldsToClearByPath['/a.mp3'], {'artist'});
    });
  });
}
