import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../tag_editor/data/providers/editor_state_provider.dart';
import '../../tag_editor/data/providers/folder_loading_provider.dart';
import '../../tag_editor/presentation/widgets/address_bar.dart';
import 'folder_validator.dart';
import 'sibling_resolver.dart';

/// Orchestrates sibling folder navigation.
///
/// Coordinates filesystem listing, sibling resolution, unsaved-changes
/// guard, folder validation, and folder loading to navigate to the
/// next or previous sibling folder.
///
/// Instantiated with a [WidgetRef] like [FolderLoadingService]:
/// ```dart
/// final service = SiblingNavigationService(ref);
/// await service.navigate(context, SiblingDirection.next);
/// ```
class SiblingNavigationService {
  /// Creates a [SiblingNavigationService] with the given [WidgetRef].
  SiblingNavigationService(this._ref);

  final WidgetRef _ref;

  /// Navigates to the next or previous sibling folder.
  ///
  /// Shows unsaved-changes guard if needed. Updates status message
  /// if at boundary or on error. No-op if no folder is currently loaded.
  Future<void> navigate(
    BuildContext context,
    SiblingDirection direction,
  ) async {
    // 1. Get current folder path — no-op if null
    final currentPath = _ref.read(loadedFolderPathProvider);
    if (currentPath == null) return;

    // 2. Get parent directory, list its subdirectories
    final parentPath = p.dirname(currentPath);
    final parentDir = Directory(parentPath);

    List<String> subdirectoryNames;
    try {
      final entities = parentDir.listSync();
      subdirectoryNames = entities
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();
    } on FileSystemException {
      _ref.read(statusMessageProvider.notifier).state =
          'Cannot access parent directory';
      return;
    }

    // 3. filterAndSort, then resolve next/previous
    final resolver = SiblingResolver();
    final sorted = resolver.filterAndSort(subdirectoryNames);
    final currentName = p.basename(currentPath);
    final targetName = resolver.resolve(
      siblingNames: sorted,
      currentName: currentName,
      direction: direction,
    );

    // 4. If null (boundary): show status message, return
    if (targetName == null) {
      final directionLabel =
          direction == SiblingDirection.next ? 'next' : 'previous';
      _ref.read(statusMessageProvider.notifier).state =
          'No $directionLabel sibling folder';
      return;
    }

    // 5. Check unsaved changes guard — abort if cancelled
    final proceed = await UnsavedChangesGuard.check(
      context: context,
      ref: _ref,
      clearUndoOnDiscard: true,
    );
    if (!proceed) return;
    if (!context.mounted) return;

    // 6. Validate target folder
    final targetPath = p.join(parentPath, targetName);
    final validator = FolderValidator();
    final result = await validator.validate(targetPath);

    // 7. If invalid: show error status message, return
    if (!result.isValid) {
      _ref.read(statusMessageProvider.notifier).state =
          'Cannot access folder: $targetName';
      return;
    }

    // 8. Load folder via FolderLoadingService
    if (!context.mounted) return;
    final loadingService = FolderLoadingService(_ref);
    await loadingService.loadFolder(context, targetPath);
  }
}
