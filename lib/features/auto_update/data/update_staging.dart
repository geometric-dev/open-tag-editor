import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The kind of staged update waiting to be applied.
enum PendingUpdateKind {
  /// A payload directory of app files to copy over the install directory.
  swap,

  /// A downloaded installer executable to run.
  installer,
}

/// A downloaded update that will be applied the next time the app starts.
///
/// Persisted as `pending.json` in the per-user updates directory so it
/// survives a reboot. On startup the app checks for one, and if present a
/// helper applies it before the UI comes up — the Chrome/Firefox model of
/// "download now, apply on next start".
class PendingUpdate {
  const PendingUpdate({
    required this.version,
    required this.kind,
    required this.sourcePath,
  });

  /// The version this update will install (e.g. "0.7.0").
  final String version;

  /// Whether to copy [sourcePath] over the install dir or run it.
  final PendingUpdateKind kind;

  /// For [PendingUpdateKind.swap]: the directory of app files.
  /// For [PendingUpdateKind.installer]: the installer executable path.
  final String sourcePath;

  factory PendingUpdate.fromJson(Map<String, dynamic> json) {
    return PendingUpdate(
      version: json['version'] as String? ?? '',
      kind: (json['kind'] as String? ?? 'swap') == 'installer'
          ? PendingUpdateKind.installer
          : PendingUpdateKind.swap,
      sourcePath: json['sourcePath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'kind': kind == PendingUpdateKind.installer ? 'installer' : 'swap',
    'sourcePath': sourcePath,
  };
}

/// Reads and writes the [PendingUpdate] marker and resolves the per-user
/// updates directory.
///
/// The directory is per-user and outside the install tree so it is writable
/// whether the app was installed per-user or per-machine, and so staged files
/// survive a reboot.
class UpdateStaging {
  const UpdateStaging();

  /// Overridable base directory, used by tests to redirect to a temp dir.
  static String? overrideBaseDir;

  /// The base directory where updates are downloaded and staged.
  static String baseDir() {
    final override = overrideBaseDir;
    if (override != null) return override;
    final home = _homeDir();
    return p.join(home, 'open_tag_editor', 'updates');
  }

  static String _homeDir() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return localAppData;
      }
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) {
        return p.join(profile, 'AppData', 'Local');
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, 'Library', 'Application Support');
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, '.local', 'share');
      }
    }
    return Directory.systemTemp.path;
  }

  /// The path of the pending-update marker file.
  static String pendingMarkerPath() => p.join(baseDir(), 'pending.json');

  /// Reads the pending update, or null if none is waiting or it is unreadable.
  static PendingUpdate? readPending() {
    try {
      final file = File(pendingMarkerPath());
      if (!file.existsSync()) return null;
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final pending = PendingUpdate.fromJson(data);
      // Guard against a corrupt marker pointing at nothing.
      if (pending.sourcePath.isEmpty) return null;
      if (!File(pending.sourcePath).existsSync() &&
          !Directory(pending.sourcePath).existsSync()) {
        return null;
      }
      return pending;
    } catch (_) {
      return null;
    }
  }

  /// Writes the pending update marker, creating the directory if needed.
  static void writePending(PendingUpdate pending) {
    final dir = Directory(baseDir());
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File(pendingMarkerPath()).writeAsStringSync(jsonEncode(pending.toJson()));
  }

  /// Removes the pending update marker (best-effort).
  static void clearPending() {
    try {
      final file = File(pendingMarkerPath());
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
