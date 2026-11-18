import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/update_info.dart';

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
      final scriptFile = File(
        p.join(payloadDir.parent.path, 'apply_update.bat'),
      );
      final script =
          '''
@echo off
set "TARGET_PID=$currentPid"
set "SRC=${payloadDir.path}"
set "DEST=$appDir"
set "EXE=$exeName"

:wait_pid
tasklist /fi "PID eq %TARGET_PID%" | find "%TARGET_PID%" >nul
if not errorlevel 1 (
    timeout /t 1 /nobreak >nul
    goto wait_pid
)

timeout /t 1 /nobreak >nul
xcopy /s /e /y "%SRC%\\*" "%DEST%\\"
start "" "%DEST%\\%EXE%"
del "%~f0"
''';
      await scriptFile.writeAsString(script);

      await Process.start('cmd.exe', [
        '/c',
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
SRC="${payloadDir.path}"
DEST="$appDir"
EXE="$exeName"

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
}
