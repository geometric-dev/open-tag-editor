import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile file({
  Map<String, String> tags = const {},
  Map<String, String>? originalTags,
  bool isModified = false,
}) {
  return AudioFile(
    path: '/a.mp3',
    filename: 'a.mp3',
    extension: '.mp3',
    fileSize: 1,
    tags: tags,
    originalTags: originalTags,
    isModified: isModified,
  );
}

void main() {
  group('mapsEqual', () {
    test('identical maps are equal', () {
      expect(mapsEqual(const {'a': '1'}, const {'a': '1'}), isTrue);
    });

    test('different lengths are unequal', () {
      expect(mapsEqual(const {'a': '1'}, const {'a': '1', 'b': '2'}), isFalse);
    });

    test('same length with a different key is unequal', () {
      expect(mapsEqual(const {'a': '1'}, const {'b': '1'}), isFalse);
    });

    test('same length with a different value is unequal', () {
      expect(mapsEqual(const {'a': '1'}, const {'a': '2'}), isFalse);
    });

    test('empty maps are equal', () {
      expect(mapsEqual(const {}, const {}), isTrue);
    });

    test('the same instance is equal without comparing', () {
      const m = {'a': '1'};
      expect(mapsEqual(m, m), isTrue);
    });
  });

  group('differsFromOriginal', () {
    test('a file with no originalTags is always considered changed', () {
      // The on-disk state is unknown, so it cannot be proven clean.
      expect(file(tags: const {}).differsFromOriginal(const {}), isTrue);
    });

    test('a value matching the original is unchanged', () {
      final f = file(
        tags: const {'title': 'x'},
        originalTags: const {'title': 'x'},
      );
      expect(f.differsFromOriginal(const {'title': 'x'}), isFalse);
    });

    test('a different value is a change', () {
      final f = file(
        tags: const {'title': 'y'},
        originalTags: const {'title': 'x'},
      );
      expect(f.differsFromOriginal(const {'title': 'y'}), isTrue);
    });

    test('a removed field is a change', () {
      final f = file(tags: const {}, originalTags: const {'title': 'x'});
      expect(f.differsFromOriginal(const {}), isTrue);
    });

    test('an added field is a change', () {
      final f = file(tags: const {'b': '2'}, originalTags: const {'a': '1'});
      expect(f.differsFromOriginal(const {'b': '2'}), isTrue);
    });
  });

  group('modifiedTags and differsFromOriginal agree', () {
    test('identical maps yield no modifications and no difference', () {
      final f = file(
        tags: const {'title': 'x', 'artist': 'y'},
        originalTags: const {'title': 'x', 'artist': 'y'},
      );

      expect(f.modifiedTags, isEmpty);
      expect(f.differsFromOriginal(f.tags), isFalse);
    });

    test('a changed field is reported by both', () {
      final f = file(
        tags: const {'title': 'z'},
        originalTags: const {'title': 'x'},
      );

      expect(f.modifiedTags, {'title': 'z'});
      expect(f.differsFromOriginal(f.tags), isTrue);
    });

    test('a removed field is an empty-string write', () {
      final f = file(tags: const {}, originalTags: const {'title': 'x'});

      // The empty string is how a removal is expressed to the writer, which
      // passes it to TagLib as nullptr.
      expect(f.modifiedTags, {'title': ''});
      expect(f.differsFromOriginal(f.tags), isTrue);
    });
  });
}
