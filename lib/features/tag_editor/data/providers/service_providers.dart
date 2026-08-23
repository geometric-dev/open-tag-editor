import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../shared/services/id3_reader_service.dart';
import '../../../../shared/services/rename_service.dart';
import '../../../../shared/services/tag_reader_service.dart';
import '../../../../shared/services/taglib/backup_manager.dart';
import '../../../../shared/services/taglib/disabled_writer_service.dart';
import '../../../../shared/services/taglib/native_library_loader.dart';
import '../../../../shared/services/taglib/taglib_bindings.g.dart';
import '../../../../shared/services/taglib/taglib_reader_service.dart';
import '../../../../shared/services/taglib/taglib_writer_service.dart';
import '../../../../shared/services/taglib/validation_engine.dart';
import '../../../settings/data/models/tag_write_options.dart';
import '../../../settings/data/providers/settings_providers.dart';
import '../providers/file_list_provider.dart';
import '../services/tag_save_service.dart';

/// Provider for the backup enabled setting.
///
/// Defaults to true. Will be connected to shared_preferences in the
/// settings page implementation.
final backupEnabledProvider = StateProvider<bool>((ref) => true);

/// Provider for the tag reader service.
///
/// Uses TagLib FFI when the native library is available,
/// falls back to the pure-Dart reader otherwise.
final tagReaderProvider = Provider<TagReaderService>((ref) {
  if (NativeLibraryLoader.isAvailable) {
    final bindings = TagLibBindings(NativeLibraryLoader.load());
    return TagLibReaderService(bindings);
  }
  return Id3ReaderService();
});

/// Provider for the tag writer service.
///
/// Uses TagLib FFI when the native library is available,
/// returns a disabled writer otherwise (never falls back to unsafe writer).
final tagWriterProvider = Provider<TagWriterService>((ref) {
  if (NativeLibraryLoader.isAvailable) {
    final bindings = TagLibBindings(NativeLibraryLoader.load());
    final backupManager = BackupManager(
      isBackupEnabled: () => ref.read(backupEnabledProvider),
    );
    final reader = ref.read(tagReaderProvider);
    final validator = ValidationEngine(reader);
    return TagLibWriterService(
      bindings,
      backupManager,
      validator,
      getWriteOptions: () => TagWriteOptions(
        id3v2Version: ref.read(tagWritingSettingsProvider).id3v2Version,
        writeId3v1: ref.read(tagWritingSettingsProvider).writeId3v1,
        encoding: ref.read(tagWritingSettingsProvider).encoding,
      ),
    );
  }
  return DisabledWriterService();
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
