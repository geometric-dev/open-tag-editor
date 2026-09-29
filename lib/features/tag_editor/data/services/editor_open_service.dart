import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/supported_formats.dart';
import '../../../../shared/widgets/unsaved_changes_guard.dart';
import '../providers/folder_loading_provider.dart';

/// The "open something" actions, shared by the toolbar and the empty state.
///
/// Extracted so the two entry points cannot drift: the empty state's buttons
/// used to be a natural thing to write a second, slightly different copy of,
/// and a second copy is how a file open ends up skipping the unsaved-changes
/// guard or the recursive toggle.
class EditorOpenService {
  EditorOpenService(this._read);

  final ProviderReader _read;

  /// Extensions offered by the multi-select file picker.
  ///
  /// Deliberately shorter than [SupportedFormats]: it is the set people
  /// actually pick, and listing 25 extensions in a native dialog helps
  /// nobody. Drag-and-drop and folder scan still accept the full set.
  static const pickableExtensions = <String>[
    'mp3',
    'flac',
    'ogg',
    'm4a',
    'mp4',
    'wma',
    'wav',
    'ape',
    'opus',
    'aac',
  ];

  /// Opens a folder picker and loads the chosen folder.
  Future<void> openFolder(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final proceed = await UnsavedChangesGuard.check(
      context: context,
      ref: ref,
      clearUndoOnDiscard: true,
    );
    if (!proceed || !context.mounted) return;

    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Music Folder',
    );
    if (result == null || !context.mounted) return;

    // Route through the shared loading service so every entry point honours
    // the recursive toggle, the threshold guard and recent-folder
    // persistence identically.
    await FolderLoadingService(_read).loadFolder(context, result);
  }

  /// Opens a file picker and loads the chosen files.
  Future<void> openFiles(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final proceed = await UnsavedChangesGuard.check(
      context: context,
      ref: ref,
      clearUndoOnDiscard: true,
    );
    if (!proceed || !context.mounted) return;

    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select Audio Files',
      type: FileType.custom,
      allowedExtensions: pickableExtensions,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();

    await FolderLoadingService(_read).loadFromDrop(context, paths);
  }

  /// Human-readable format summary for the empty state, e.g.
  /// "MP3, FLAC, OGG, M4A, WMA, WAV, APE and 14 more".
  static String formatSummary({int max = 7}) {
    final names = <String>[
      for (final ext in SupportedFormats.all)
        ext.replaceFirst('.', '').toUpperCase(),
    ];
    if (names.length <= max) return names.join(', ');
    final shown = names.take(max).join(', ');
    return '$shown and ${names.length - max} more';
  }
}
