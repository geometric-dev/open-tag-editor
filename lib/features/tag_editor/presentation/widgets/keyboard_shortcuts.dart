import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../features/folder_panel/data/sibling_navigation_service.dart';
import '../../../../features/folder_panel/data/sibling_resolver.dart';
import '../../../../features/folder_panel/presentation/quick_switcher_overlay.dart';
import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../../data/providers/editor_state_provider.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/folder_loading_provider.dart';
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
          _saveAll(context, ref);
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          final files = ref.read(fileListProvider);
          ref.read(selectionProvider.notifier)
              .selectAll(files.map((f) => f.path).toList());
        },
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): () {
          QuickSwitcherOverlay.show(context, ref, (path) async {
            final proceed = await UnsavedChangesGuard.check(
              context: context,
              ref: ref,
              clearUndoOnDiscard: true,
            );
            if (!proceed || !context.mounted) return;
            final service = FolderLoadingService(ref);
            await service.loadFolder(context, path);
          });
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
          final service = SiblingNavigationService(ref);
          service.navigate(context, SiblingDirection.next);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          final service = SiblingNavigationService(ref);
          service.navigate(context, SiblingDirection.previous);
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  Future<void> _saveAll(BuildContext context, WidgetRef ref) async {
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
      final changed = file.modifiedTags;
      if (changed.isNotEmpty) {
        fileTagsMap[file.path] = changed;
      }
    }

    if (fileTagsMap.isEmpty) {
      statusNotifier.state = 'No changes to save';
      return;
    }

    final results = await writer.writeTagsBatch(fileTagsMap);
    final successCount = results.where((r) => r.success).length;

    final updatedFiles = modifiedFiles
        .where((f) => results.any((r) => r.path == f.path && r.success))
        .map((f) => f.copyWith(
              isModified: false,
              originalTags: Map<String, String>.unmodifiable(f.tags),
            ),)
        .toList();
    notifier.updateFiles(updatedFiles);

    statusNotifier.state = 'Saved $successCount file(s)';
  }
}
