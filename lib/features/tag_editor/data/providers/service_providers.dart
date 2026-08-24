import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/rename_service.dart';
import '../../../../shared/services/tag_reader_service.dart';
import '../../../../shared/services/taglib/backup_manager.dart';
import '../../../../shared/services/taglib/disabled_writer_service.dart';
import '../../../../shared/services/taglib/isolate_tag_io.dart';
import '../../../../shared/services/taglib/isolate_tag_reader_service.dart';
import '../../../../shared/services/taglib/isolate_tag_writer_service.dart';
import '../../../../shared/services/taglib/native_library_loader.dart';
import '../../../../shared/services/taglib/taglib_bindings.g.dart';
import '../../../../shared/services/taglib/taglib_writer_service.dart';
import '../../../../shared/services/taglib/validation_engine.dart';
import '../../../settings/data/models/tag_write_options.dart';
import '../../../settings/data/providers/settings_providers.dart';
import '../providers/file_list_provider.dart';
import '../services/tag_save_service.dart';

/// Provider for the tag reader service.
///
/// Single-file reads use the best available implementation directly;
/// batch reads (folder loads) run on a background isolate so the UI
/// stays responsive with large libraries. Falls back to the pure-Dart
/// reader when the native library is unavailable.
final tagReaderProvider = Provider<TagReaderService>((ref) {
  return IsolateTagReaderService();
});

/// Provider for the tag writer service.
///
/// Uses TagLib FFI when the native library is available: single-file
/// writes run directly, batch saves run on a background isolate with a
/// settings snapshot. Returns a disabled writer otherwise (never falls
/// back to an unsafe writer).
final tagWriterProvider = Provider<TagWriterService>((ref) {
  if (!NativeLibraryLoader.isAvailable) {
    return DisabledWriterService();
  }

  TagWriteOptions writeOptions() => TagWriteOptions(
        id3v2Version: ref.read(tagWritingSettingsProvider).id3v2Version,
        writeId3v1: ref.read(tagWritingSettingsProvider).writeId3v1,
        encoding: ref.read(tagWritingSettingsProvider).encoding,
      );

  return IsolateTagWriterService(
    getSnapshot: () => TagWriteSettingsSnapshot(
      backupEnabled: ref.read(generalSettingsProvider).backupEnabled,
      preserveTimestamp:
          ref.read(generalSettingsProvider).preserveTimestamp,
      options: writeOptions(),
    ),
    createDirectWriter: () {
      final bindings = TagLibBindings(NativeLibraryLoader.load());
      return TagLibWriterService(
        bindings,
        BackupManager(
          isBackupEnabled: () =>
              ref.read(generalSettingsProvider).backupEnabled,
        ),
        ValidationEngine(ref.read(tagReaderProvider)),
        getWriteOptions: writeOptions,
        isPreserveTimestampEnabled: () =>
            ref.read(generalSettingsProvider).preserveTimestamp,
      );
    },
  );
});

/// Provider for the rename service.
final renameServiceProvider = Provider<RenameService>((ref) {
  return RenameService();
});

/// Provider for the batch tag-save service.
///
/// Single save flow shared by the toolbar, Ctrl+S shortcut, the tag
/// panel's Save button, and the unsaved-changes guard.
final tagSaveServiceProvider = Provider<TagSaveService>((ref) {
  return TagSaveService(
    writer: ref.watch(tagWriterProvider),
    fileListNotifier: ref.read(fileListProvider.notifier),
  );
});
