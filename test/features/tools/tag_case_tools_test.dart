import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tools/data/tag_case_tools.dart';
import 'package:open_tag_editor/features/tools/data/tag_transform_command.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile file(String path, Map<String, String> tags) => AudioFile(
      path: path,
      filename: path.split('/').last,
      extension: '.mp3',
      fileSize: 1,
      tags: tags,
      originalTags: Map.unmodifiable(tags),
    );

void main() {
  group('artist transforms', () {
    test('theToComma preserves the article as written', () {
      expect(theToComma('a tribe called quest'), 'tribe called quest, a');
    });

    test('theToComma leaves names without articles', () {
      expect(theToComma('Radiohead'), 'Radiohead');
    });

    test('commaToThe restores the article', () {
      expect(commaToThe('Beatles, The'), 'The Beatles');
      expect(commaToThe('Ocean, An'), 'An Ocean');
      expect(commaToThe('Simon & Garfunkel'), 'Simon & Garfunkel');
    });

    test('transforms are inverse of each other', () {
      const name = 'The Smashing Pumpkins';
      expect(commaToThe(theToComma(name)), name);
    });

    test('applyTool produces delta only for changed fields', () {
      final delta = applyTool(
        TagTool.artistTheToComma,
        file('/a.mp3',
            {'artist': 'The Who', 'albumArtist': 'Who', 'title': 'X'}),
      );
      expect(delta, {'artist': 'Who, The'});
      // albumArtist 'Who' has no article -> unchanged -> not in delta.
    });
  });

  group('TagTransformCommand', () {
    late FileListNotifier notifier;

    setUp(() {
      notifier = FileListNotifier();
    });

    test('applies per-file deltas and marks files modified', () {
      notifier.addFiles([
        file('/a.mp3', {'artist': 'The Who'}),
        file('/b.mp3', {'artist': 'The Clash'}),
        file('/c.mp3', {'artist': 'Pulp'}),
      ]);

      final command = TagTransformCommand(
        fileListNotifier: notifier,
        deltas: {
          '/a.mp3': {'artist': 'Who, The'},
          '/b.mp3': {'artist': 'Clash, The'},
          // /c.mp3 intentionally omitted (no change).
        },
        previousTags: {
          '/a.mp3': {'artist': 'The Who'},
          '/b.mp3': {'artist': 'The Clash'},
          '/c.mp3': {'artist': 'Pulp'},
        },
        description: "Format 'The Artist' to 'Artist, The' (2 files)",
      )..execute();

      final byPath = {for (final f in notifier.currentFiles) f.path: f};
      expect(byPath['/a.mp3']!.tags['artist'], 'Who, The');
      expect(byPath['/b.mp3']!.tags['artist'], 'Clash, The');
      expect(byPath['/c.mp3']!.tags['artist'], 'Pulp');
      expect(byPath['/a.mp3']!.isModified, isTrue);
      expect(byPath['/c.mp3']!.isModified, isFalse);

      command.undo();

      final restored = {for (final f in notifier.currentFiles) f.path: f};
      expect(restored['/a.mp3']!.tags['artist'], 'The Who');
      expect(restored['/a.mp3']!.isModified, isFalse);
      expect(restored['/b.mp3']!.tags['artist'], 'The Clash');
    });

    test('undo recomputes dirty state against originalTags', () {
      final original = {'artist': 'Was'};
      final audio = AudioFile(
        path: '/x.mp3',
        filename: 'x.mp3',
        extension: '.mp3',
        fileSize: 1,
        tags: original,
        originalTags: Map.unmodifiable(original),
      );
      notifier.addFiles([audio]);

      final command = TagTransformCommand(
        fileListNotifier: notifier,
        deltas: {
          '/x.mp3': {'artist': 'Now'},
        },
        previousTags: {
          '/x.mp3': Map.of(original),
        },
        description: 'test',
      )..execute();
      expect(notifier.currentFiles.single.isModified, isTrue);

      command.undo();
      expect(notifier.currentFiles.single.isModified, isFalse);
    });
  });
}
