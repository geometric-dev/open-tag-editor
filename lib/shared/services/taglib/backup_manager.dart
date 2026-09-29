import 'dart:io';

import '../tag_reader_service.dart';

/// Manages `.bak` backup copies of files before modification.
///
/// Uses a callback to dynamically check whether backups are enabled,
/// allowing settings changes to take effect without restarting.
class BackupManager {
  /// Creates a [BackupManager] that checks [isBackupEnabled] to determine
  /// whether backups should be created.
  BackupManager({required bool Function() isBackupEnabled})
    : _isBackupEnabled = isBackupEnabled;

  final bool Function() _isBackupEnabled;

  /// Whether backup is currently enabled.
  bool get isEnabled => _isBackupEnabled();

  /// Creates a backup of [path] as `<path>.bak` if backup is enabled.
  ///
  /// If backup is enabled and the copy fails, throws [TagWriteException].
  /// If backup is disabled, this is a no-op.
  Future<void> createBackupIfEnabled(String path) async {
    if (!isEnabled) {
      return;
    }

    try {
      final file = File(path);
      await file.copy('$path.bak');
    } catch (e) {
      throw TagWriteException('Failed to create backup: $e', path);
    }
  }
}
