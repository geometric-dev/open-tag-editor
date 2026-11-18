import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/selection_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

void main() {
  group('FileListNotifier rename and error flagging', () {
    late FileListNotifier notifier;

    setUp(() {
      notifier = FileListNotifier();
      notifier.addFiles([
        const AudioFile(
          path: r'C:\Music\old1.mp3',
          filename: 'old1.mp3',
          extension: '.mp3',
          fileSize: 1024,
          tags: {'title': 'Track One'},
        ),
        const AudioFile(
          path: r'C:\Music\old2.mp3',
          filename: 'old2.mp3',
          extension: '.mp3',
          fileSize: 2048,
          tags: {'title': 'Track Two'},
        ),
      ]);
    });

    test(
      'applyRenames updates path, filename, and extension while preserving tags',
      () {
        notifier.applyRenames({
          r'C:\Music\old1.mp3': r'C:\Music\01 - Track One.mp3',
        });

        final files = notifier.currentFiles;
        expect(files.length, 2);
        expect(files[0].path, r'C:\Music\01 - Track One.mp3');
        expect(files[0].filename, '01 - Track One.mp3');
        expect(files[0].extension, '.mp3');
        expect(files[0].tags['title'], 'Track One');

        // Untouched file remains unchanged
        expect(files[1].path, r'C:\Music\old2.mp3');
      },
    );

    test('setFileErrors flags readError on specified files', () {
      notifier.setFileErrors({
        r'C:\Music\old2.mp3': 'Rename failed: Permission denied',
      });

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
        notifier.select(r'C:\Music\old1.mp3');

        expect(notifier.state.selectedPaths, {r'C:\Music\old1.mp3'});
        expect(notifier.state.anchorPath, r'C:\Music\old1.mp3');

        notifier.remapPaths({r'C:\Music\old1.mp3': r'C:\Music\new1.mp3'});

        expect(notifier.state.selectedPaths, {r'C:\Music\new1.mp3'});
        expect(notifier.state.anchorPath, r'C:\Music\new1.mp3');
      },
    );
  });
}
