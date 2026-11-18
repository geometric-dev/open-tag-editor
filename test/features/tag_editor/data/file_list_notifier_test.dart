import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/selection_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileListNotifier rename and error flagging', () {
    late FileListNotifier notifier;

    // Paths are assembled with the platform separator: applyRenames parses
    // the filename with `p.basename`, whose rules are platform-specific, so
    // a hardcoded Windows path would parse differently on the Linux CI.
    final musicDir = p.join('music');
    final old1 = p.join(musicDir, 'old1.mp3');
    final old2 = p.join(musicDir, 'old2.mp3');
    final renamed1 = p.join(musicDir, '01 - Track One.mp3');

    setUp(() {
      notifier = FileListNotifier();
      notifier.addFiles([
        AudioFile(
          path: old1,
          filename: 'old1.mp3',
          extension: '.mp3',
          fileSize: 1024,
          tags: const {'title': 'Track One'},
        ),
        AudioFile(
          path: old2,
          filename: 'old2.mp3',
          extension: '.mp3',
          fileSize: 2048,
          tags: const {'title': 'Track Two'},
        ),
      ]);
    });

    test(
      'applyRenames updates path, filename, and extension while preserving tags',
      () {
        notifier.applyRenames({old1: renamed1});

        final files = notifier.currentFiles;
        expect(files.length, 2);
        expect(files[0].path, renamed1);
        expect(files[0].filename, '01 - Track One.mp3');
        expect(files[0].extension, '.mp3');
        expect(files[0].tags['title'], 'Track One');

        // Untouched file remains unchanged
        expect(files[1].path, old2);
      },
    );

    test('setFileErrors flags readError on specified files', () {
      notifier.setFileErrors({old2: 'Rename failed: Permission denied'});

      final files = notifier.currentFiles;
      expect(files[0].readError, isNull);
      expect(files[1].readError, 'Rename failed: Permission denied');
    });
  });

  group('SelectionNotifier.remapPaths', () {
    test(
      'updates selected paths and anchor/active paths when paths are renamed',
      () {
        final notifier = SelectionNotifier();
        final old1 = p.join('music', 'old1.mp3');
        final new1 = p.join('music', 'new1.mp3');
        notifier.select(old1);

        expect(notifier.state.selectedPaths, {old1});
        expect(notifier.state.anchorPath, old1);

        notifier.remapPaths({old1: new1});

        expect(notifier.state.selectedPaths, {new1});
        expect(notifier.state.anchorPath, new1);
      },
    );
  });
}
