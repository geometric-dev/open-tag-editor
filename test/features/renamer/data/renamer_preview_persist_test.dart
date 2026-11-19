import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/undo/undo_redo_manager.dart';
import 'package:open_tag_editor/features/renamer/data/models/rename_preview.dart';
import 'package:open_tag_editor/features/renamer/data/providers/renamer_providers.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/selection_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile _file(String path, String title) => AudioFile(
  path: path,
  filename: path.split('/').last,
  extension: '.mp3',
  fileSize: 1,
  tags: {'title': title},
);

void main() {
  test('renamer previews survive a selection change (autoDispose)', () {
    final container = ProviderContainer(
      overrides: [undoRedoProvider.overrideWith((ref) => UndoRedoManager())],
    );
    addTearDown(container.dispose);

    container.read(fileListProvider.notifier).addFiles([
      _file('/a.mp3', 'One'),
      _file('/b.mp3', 'Two'),
    ]);
    container.read(selectionProvider.notifier).select('/a.mp3');

    // Keep the provider alive the way an open dialog does.
    final listener = container.listen(
      renamerStateProvider,
      (_, _) {},
      fireImmediately: true,
    );

    container.read(renamerStateProvider.notifier).setPattern('%title');
    final before = container.read(renamerStateProvider).previews;
    expect(before, isNotEmpty);

    // A rename remaps the selection to new paths.
    container.read(selectionProvider.notifier).select('/b.mp3');
    final after = container.read(renamerStateProvider).previews;

    // The previews should still be present (regenerated for the new selection),
    // not blanked out because the provider was disposed and recreated.
    expect(after, isNotEmpty);
    expect(after.first.status, RenamePreviewStatus.ok);

    listener.close();
  });
}
