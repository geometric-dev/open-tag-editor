import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../data/providers/editor_state_provider.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/selection_provider.dart';
import '../../data/providers/service_providers.dart';

/// Wraps a child widget with keyboard shortcut handlers for the editor.
class EditorKeyboardShortcuts extends ConsumerWidget {
  const EditorKeyboardShortcuts({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          ref.read(undoRedoProvider.notifier).undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          ref.read(undoRedoProvider.notifier).redo();
        },
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () {
          ref.read(undoRedoProvider.notifier).redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          _saveAll(ref);
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          final files = ref.read(fileListProvider);
          ref.read(selectionProvider.notifier)
              .selectAll(files.map((f) => f.path).toList());
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  Future<void> _saveAll(WidgetRef ref) async {
    final files = ref.read(fileListProvider);
    final writer = ref.read(tagWriterProvider);
    final notifier = ref.read(fileListProvider.notifier);
    final statusNotifier = ref.read(statusMessageProvider.notifier);

    final modifiedFiles = files.where((f) => f.isModified).toList();
    if (modifiedFiles.isEmpty) {
      statusNotifier.state = 'No changes to save';
      return;
    }

    statusNotifier.state = 'Saving ${modifiedFiles.length} file(s)...';

    final fileTagsMap = <String, Map<String, String>>{};
    for (final file in modifiedFiles) {
      fileTagsMap[file.path] = file.tags;
    }

    final results = await writer.writeTagsBatch(fileTagsMap);
    final successCount = results.where((r) => r.success).length;

    final updatedFiles = modifiedFiles
        .where((f) => results.any((r) => r.path == f.path && r.success))
        .map((f) => f.copyWith(isModified: false))
        .toList();
    notifier.updateFiles(updatedFiles);

    statusNotifier.state = 'Saved $successCount file(s)';
  }
}
