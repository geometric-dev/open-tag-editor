import 'package:flutter/foundation.dart';

import '../../../../features/settings/data/models/tag_write_options.dart';
import '../id3_reader_service.dart';
import '../tag_reader_service.dart';
import 'backup_manager.dart';
import 'native_library_loader.dart';
import 'taglib_bindings.g.dart';
import 'taglib_reader_service.dart';
import 'taglib_writer_service.dart';
import 'validation_engine.dart';

/// Creates the best available [TagReaderService] for this platform.
///
/// Safe to call from ANY isolate: native handles are per-isolate, so each
/// worker reconstructs its own bindings instead of receiving pointers.
TagReaderService createPlatformTagReaderService() {
  if (NativeLibraryLoader.isAvailable) {
    final bindings = TagLibBindings(NativeLibraryLoader.load());
    return TagLibReaderService(bindings);
  }
  return Id3ReaderService();
}

/// Plain-value snapshot of everything the native writer needs.
///
/// Callbacks (settings getters, backup-enabled checks) cannot cross isolate
/// boundaries, so they are resolved on the caller's isolate and sent as
/// sendable data.
@immutable
class TagWriteSettingsSnapshot {
  const TagWriteSettingsSnapshot({
    required this.backupEnabled,
    required this.preserveTimestamp,
    required this.options,
  });

  /// Whether `.bak` backups should be created before writing.
  final bool backupEnabled;

  /// Whether to restore original file modification time after writing.
  final bool preserveTimestamp;

  /// ID3v2 version / encoding / v1 companion settings.
  final TagWriteOptions options;
}

/// Creates a fully wired native writer from a [TagWriteSettingsSnapshot].
///
/// Returns null when the native library is unavailable in this isolate.
/// Must be called in the isolate that will perform the writes.
TagLibWriterService? createNativeTagWriterFromSnapshot(
  TagWriteSettingsSnapshot snapshot,
) {
  if (!NativeLibraryLoader.isAvailable) return null;

  final bindings = TagLibBindings(NativeLibraryLoader.load());
  final reader = TagLibReaderService(bindings);
  return TagLibWriterService(
    bindings,
    BackupManager(isBackupEnabled: () => snapshot.backupEnabled),
    ValidationEngine(reader),
    getWriteOptions: () => snapshot.options,
    isPreserveTimestampEnabled: () => snapshot.preserveTimestamp,
  );
}
