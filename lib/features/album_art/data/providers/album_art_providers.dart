import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../tag_editor/data/providers/file_list_provider.dart';
import '../../../tag_editor/data/providers/service_providers.dart';
import '../album_art_manager.dart';

/// Provider for the [AlbumArtManager] service.
///
/// Depends on the tag writer service, file list notifier, and undo/redo manager.
final albumArtManagerProvider = Provider<AlbumArtManager>((ref) {
  final tagWriter = ref.read(tagWriterProvider);
  final fileListNotifier = ref.read(fileListProvider.notifier);
  final undoRedoManager = ref.read(undoRedoProvider.notifier);

  return AlbumArtManager(
    tagWriter: tagWriter,
    fileListNotifier: fileListNotifier,
    undoRedoManager: undoRedoManager,
  );
});
