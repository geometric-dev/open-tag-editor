import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/error_handling/utils/error_entry_factory.dart';
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
          ref
              .read(selectionProvider.notifier)
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
            final service = FolderLoadingService(ref.read);
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
    final statusNotifier = ref.read(statusMessageProvider.notifier);

    statusNotifier.state = 'Saving...';

    final summary = await ref.read(tagSaveServiceProvider).saveAllModified();

    if (summary == null) {
      statusNotifier.state = 'No changes to save';
      return;
    }

    if (!summary.allSuccess) {
      // Report failures to error log (parity with the toolbar save path).
      final entries = ErrorEntryFactory.fromWriteResults(
        summary.results,
        summary.attemptedTags,
      );
      ref.read(errorLogProvider.notifier).addEntries(entries);
      statusNotifier.state =
          'Saved ${summary.successCount} file(s), ${summary.failureCount} failed';
    } else {
      statusNotifier.state = 'Saved ${summary.successCount} file(s)';
    }
  }
}
