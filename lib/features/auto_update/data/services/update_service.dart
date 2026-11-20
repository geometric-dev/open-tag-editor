import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/update_info.dart';
import '../update_staging.dart';

/// Handles checking GitHub for new releases, streaming downloads,
/// staging update archives, and executing the restart swap.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String repoOwner = 'geometric-dev';
  static const String repoName = 'open-tag-editor';

  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static const String fallbackReleaseWebUrl =
      'https://github.com/$repoOwner/$repoName/releases/latest';

  /// Queries GitHub's releases API for the latest published release.
  ///
  /// Returns [UpdateInfo] if a release was found, or null if no valid release.
  Future<UpdateInfo?> fetchLatestRelease() async {
    final uri = Uri.parse(latestReleaseApiUrl);
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'OpenTagEditor-AutoUpdate',
      },
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to check for updates: GitHub API returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return UpdateInfo.fromGitHubJson(data);
  }

  /// Downloads and extracts the update archive for [info] into a staging directory.
  ///
  /// Emits progress via [onProgress] as bytes are received.
  /// Returns the directory containing the ready-to-swap executable payload.
  Future<Directory> downloadAndStageUpdate(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    Directory? customStagingDir,
  }) async {
    if (info.assetDownloadUrl.isEmpty) {
      throw const FormatException(
        'No compatible asset download found for your operating system.',
      );
    }

    final baseDir =
        customStagingDir ??
        Directory(p.join(Directory.systemTemp.path, 'open_tag_editor_updates'));

    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }

    final assetFile = File(p.join(baseDir.path, info.assetName));
    final tmpFile = File('${assetFile.path}.tmp');
    if (tmpFile.existsSync()) {
      try {
        tmpFile.deleteSync();
      } catch (_) {}
    }

    // Stream download
    final request = http.Request('GET', Uri.parse(info.assetDownloadUrl));
    request.headers['User-Agent'] = 'OpenTagEditor-AutoUpdate';
    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      throw HttpException(
        'Download failed with HTTP ${streamedResponse.statusCode}',
        uri: Uri.parse(info.assetDownloadUrl),
      );
    }

    final totalBytes = streamedResponse.contentLength ?? info.assetSize;
    var receivedBytes = 0;

    final sink = tmpFile.openWrite();
    try {
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, totalBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (assetFile.existsSync()) {
      try {
        assetFile.deleteSync();
      } catch (_) {}
    }
    tmpFile.renameSync(assetFile.path);

    // Extract archive
    final stagedDir = Directory(p.join(baseDir.path, 'staged'));
    if (stagedDir.existsSync()) {
      try {
        stagedDir.deleteSync(recursive: true);
      } catch (_) {}
    }
    stagedDir.createSync(recursive: true);

    await _extractArchive(assetFile, stagedDir);

    // Resolve directory containing the actual app files
    return _resolveAppPayloadDir(stagedDir);
  }

  /// Extracts [archiveFile] into [destinationDir].
  Future<void> _extractArchive(
    File archiveFile,
    Directory destinationDir,
  ) async {
    final bytes = await archiveFile.readAsBytes();
    final lowerName = archiveFile.path.toLowerCase();

    if (lowerName.endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final outPath = p.join(destinationDir.path, file.name);
        if (file.isFile) {
          final outFile = File(outPath);
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
    } else if (lowerName.endsWith('.tar.gz') || lowerName.endsWith('.tgz')) {
      final decompressed = const GZipDecoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(decompressed);
      for (final file in archive) {
        final outPath = p.join(destinationDir.path, file.name);
        if (file.isFile) {
          final outFile = File(outPath);
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
    } else {
      throw UnsupportedError(
        'Unsupported archive format for update: ${archiveFile.path}',
      );
    }
  }

  /// Finds the directory inside [stagedDir] that holds the app executable.
  Directory _resolveAppPayloadDir(Directory stagedDir) {
    final exeName = Platform.isWindows
        ? 'open_tag_editor.exe'
        : 'open_tag_editor';
    if (File(p.join(stagedDir.path, exeName)).existsSync()) {
      return stagedDir;
    }

    // Inspect subdirectories (e.g. if root archive directory was zipped)
    for (final entity in stagedDir.listSync()) {
      if (entity is Directory) {
        if (File(p.join(entity.path, exeName)).existsSync()) {
          return entity;
        }
      }
    }
    return stagedDir;
  }

  /// Executes swap on restart.
  ///
  /// Spawns a detached background helper script, waits for the current
  /// PID to exit, copies the [payloadDir] files over the app directory,
  /// and relaunches the executable.
  Future<void> applyUpdateAndRestart({
    required Directory payloadDir,
    String? currentExecutablePath,
    bool preventExitForTesting = false,
  }) async {
    final exePath = currentExecutablePath ?? Platform.resolvedExecutable;
    final appDir = p.dirname(exePath);
    final exeName = p.basename(exePath);
    final currentPid = pid;

    // Do not run destructive swap if running inside tests or dev flutter runner
    final exeLower = exeName.toLowerCase();
    if (exeLower.contains('flutter_tester') || exeLower.contains('dart')) {
      if (preventExitForTesting) return;
    }

    if (Platform.isWindows) {
      // A PowerShell helper rather than a .bat: the batch version polled for
      // the PID with `tasklist | find`, which needs a real console to behave
      // and so opened a visible terminal window that then sat spinning. This
      // script waits on the process by PID with `Wait-Process`, copies the
      // payload over the install directory, relaunches, and removes itself.
      // It is launched with -WindowStyle Hidden so no window appears.
      final scriptFile = File(
        p.join(payloadDir.parent.path, 'apply_update.ps1'),
      );
      await scriptFile.writeAsString(
        buildWindowsUpdateScript(
          targetPid: currentPid,
          srcDir: payloadDir.path,
          destDir: appDir,
          exeName: exeName,
          relaunch: true,
          clearMarker: UpdateStaging.pendingMarkerPath(),
        ),
      );

      // -NoProfile keeps startup fast and deterministic; -ExecutionPolicy
      // Bypass allows the script to run without a signed/trusted policy;
      // -WindowStyle Hidden prevents the console window from flashing.
      await Process.start('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        scriptFile.path,
      ], mode: ProcessStartMode.detached);
    } else {
      final scriptFile = File(
        p.join(payloadDir.parent.path, 'apply_update.sh'),
      );
      final script =
          '''
#!/usr/bin/env bash
TARGET_PID=$currentPid
SRC='${_shEscape(payloadDir.path)}'
DEST='${_shEscape(appDir)}'
EXE='${_shEscape(exeName)}'

while kill -0 \$TARGET_PID 2>/dev/null; do
    sleep 1
done

sleep 1
cp -R "\$SRC/"* "\$DEST/"
"\$DEST/\$EXE" &
rm -- "\$0"
''';
      await scriptFile.writeAsString(script);
      await Process.run('chmod', ['+x', scriptFile.path]);

      await Process.start('bash', [
        scriptFile.path,
      ], mode: ProcessStartMode.detached);
    }

    if (!preventExitForTesting) {
      exit(0);
    }
  }

  /// Escapes [value] for inclusion inside a single-quoted POSIX shell string.
  ///
  /// A single quote inside a single-quoted string is written as `'\''`
  /// (close the quote, an escaped quote, reopen). This keeps a path
  /// containing `'` or `$` literal.
  static String _shEscape(String value) => value.replaceAll("'", "'\\''");

  /// Applies a previously staged update on startup, if one is waiting.
  ///
  /// This is the Chrome/Firefox-style "apply on next start" step: a prior run
  /// downloaded and staged an update and wrote a pending marker; this reads
  /// that marker and swaps the payload in.
  ///
  /// The app cannot replace its own files while it is running, so when a
  /// pending swap is found this launches a detached helper that waits for this
  /// process to exit, copies the payload over the install dir, clears the
  /// marker, and relaunches — and then returns **true** to tell the caller to
  /// exit now. The caller (`main`) calls `exit(0)` so the helper can proceed.
  ///
  /// Returns true if the caller should exit to let an update apply.
  ///
  /// A failure here never blocks startup and leaves the marker in place so the
  /// next start can retry.
  Future<bool> applyPendingUpdateIfAny({String? currentExecutablePath}) async {
    final pending = UpdateStaging.readPending();
    if (pending == null) return false;

    final exePath = currentExecutablePath ?? Platform.resolvedExecutable;
    final appDir = p.dirname(exePath);
    final exeName = p.basename(exePath);
    final currentPid = pid;

    try {
      if (pending.kind == PendingUpdateKind.installer) {
        await _launchInstaller(pending.sourcePath);
        UpdateStaging.clearPending();
        return true;
      }

      final payloadDir = Directory(pending.sourcePath);
      if (Platform.isWindows) {
        final scriptFile = File(
          p.join(UpdateStaging.baseDir(), 'apply_update_startup.ps1'),
        );
        await scriptFile.writeAsString(
          buildWindowsUpdateScript(
            targetPid: currentPid,
            srcDir: payloadDir.path,
            destDir: appDir,
            exeName: exeName,
            relaunch: true,
            clearMarker: UpdateStaging.pendingMarkerPath(),
          ),
        );
        await Process.start('powershell.exe', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          scriptFile.path,
        ], mode: ProcessStartMode.detached);
      } else {
        final scriptFile = File(
          p.join(UpdateStaging.baseDir(), 'apply_update_startup.sh'),
        );
        await scriptFile.writeAsString(
          _buildPosixStartupSwapScript(
            targetPid: currentPid,
            srcDir: payloadDir.path,
            destDir: appDir,
            exeName: exeName,
            clearMarker: UpdateStaging.pendingMarkerPath(),
          ),
        );
        await Process.run('chmod', ['+x', scriptFile.path]);
        await Process.start('bash', [
          scriptFile.path,
        ], mode: ProcessStartMode.detached);
      }
      return true;
    } catch (_) {
      // A failed pending apply must not stop the app from starting; leave the
      // marker in place so the next start can retry.
      return false;
    }
  }

  /// Launches a downloaded installer and exits so it can replace the app.
  Future<void> _launchInstaller(String installerPath) async {
    if (Platform.isWindows) {
      await Process.start(installerPath, [
        '/SILENT',
      ], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      // A .dmg/.pkg would be opened; the installer asset for macOS is the
      // .app tar, so this path is effectively unused today.
      await Process.start('open', [
        installerPath,
      ], mode: ProcessStartMode.detached);
    } else {
      await Process.start(installerPath, [], mode: ProcessStartMode.detached);
    }
  }

  /// Builds the POSIX startup-swap script.
  String _buildPosixStartupSwapScript({
    required int targetPid,
    required String srcDir,
    required String destDir,
    required String exeName,
    String? clearMarker,
  }) {
    final clearLine = clearMarker != null
        ? 'rm -f \'${_shEscape(clearMarker)}\''
        : '';
    return '''
#!/usr/bin/env bash
TARGET_PID=$targetPid
SRC='${_shEscape(srcDir)}'
DEST='${_shEscape(destDir)}'
EXE='${_shEscape(exeName)}'

while kill -0 \$TARGET_PID 2>/dev/null; do
    sleep 1
done

sleep 1
cp -R "\$SRC/"* "\$DEST/"
$clearLine
"\$DEST/\$EXE" &
rm -- "\$0"
''';
  }
}

/// Builds the Windows helper script that applies a downloaded update.
///
/// The app launches this detached, then exits. The script waits for the app
/// process ([targetPid]) to exit, copies the staged payload ([srcDir]) over
/// the install directory ([destDir]), relaunches [exeName], and deletes
/// itself.
///
/// Deliberately a PowerShell script using `Wait-Process`, not a `.bat` that
/// polls with `tasklist | find`: the batch form needs a real console to work
/// and opened a visible terminal window that then spun indefinitely. Keeping
/// this as a pure function lets a test assert that regression stays fixed.
String buildWindowsUpdateScript({
  required int targetPid,
  required String srcDir,
  required String destDir,
  required String exeName,
  bool relaunch = true,
  String? clearMarker,
}) {
  final src = srcDir.replaceAll("'", "''");
  final dest = destDir.replaceAll("'", "''");
  final exe = exeName.replaceAll("'", "''");
  final relaunchLine = relaunch
      ? '''
Start-Process -FilePath (Join-Path \$dest \$exe)'''
      : '';
  final clearLine = clearMarker != null
      ? '''
Remove-Item -LiteralPath '${clearMarker.replaceAll("'", "''")}' -Force -ErrorAction SilentlyContinue'''
      : '';
  return '''
\$ErrorActionPreference = 'Stop'
\$targetPid = $targetPid
\$src = '$src'
\$dest = '$dest'
\$exe = '$exe'

try {
    Wait-Process -Id \$targetPid -ErrorAction SilentlyContinue
} catch {}

# Give the OS a moment to release file handles on the old executable.
Start-Sleep -Milliseconds 1000

# Copy the payload over the install directory, overwriting in place.
Copy-Item -Path (Join-Path \$src '*') -Destination \$dest -Recurse -Force
$clearLine$relaunchLine

# Remove this helper script; best-effort.
Remove-Item -LiteralPath \$PSCommandPath -Force -ErrorAction SilentlyContinue
''';
}
