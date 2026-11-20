import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/app_version.dart';
import '../models/update_state.dart';
import '../services/update_service.dart';
import '../update_staging.dart';

/// Provider for the [UpdateService].
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

/// StateNotifierProvider managing the application update lifecycle.
final updateStateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((
  ref,
) {
  final service = ref.watch(updateServiceProvider);
  return UpdateNotifier(service);
});

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier(this._service, {AppVersion? currentVersion})
    : super(
        UpdateState(
          status: UpdateStatus.idle,
          currentVersion: currentVersion ?? AppVersion.current,
        ),
      );

  final UpdateService _service;
  Directory? _stagedPayloadDir;

  Directory? get stagedPayloadDir => _stagedPayloadDir;

  /// Checks GitHub for a newer version.
  ///
  /// If [autoDownload] is true and a newer version exists, starts downloading
  /// the update in the background immediately.
  Future<void> checkForUpdate({bool autoDownload = false}) async {
    if (state.isBusy) return;

    state = state.copyWith(
      status: UpdateStatus.checking,
      clearErrorMessage: true,
    );

    try {
      final info = await _service.fetchLatestRelease();

      if (info == null) {
        state = state.copyWith(status: UpdateStatus.upToDate);
        return;
      }

      if (info.version.isNewerThan(state.currentVersion)) {
        state = state.copyWith(
          status: UpdateStatus.updateAvailable,
          updateInfo: info,
          releaseUrl: info.htmlUrl,
        );

        if (autoDownload) {
          await startDownload();
        }
      } else {
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          updateInfo: info,
          releaseUrl: info.htmlUrl,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: 'Unable to check for updates: $e',
        releaseUrl: UpdateService.fallbackReleaseWebUrl,
      );
    }
  }

  /// Downloads and stages the update archive in the background.
  Future<void> startDownload({Directory? customStagingDir}) async {
    final info = state.updateInfo;
    if (info == null) return;

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadedBytes: 0,
      totalBytes: info.assetSize,
      clearErrorMessage: true,
    );

    var lastNotifyTime = DateTime.now();
    var lastNotifyBytes = 0;

    try {
      final payloadDir = await _service.downloadAndStageUpdate(
        info,
        customStagingDir: customStagingDir,
        onProgress: (received, total) {
          final now = DateTime.now();
          // Throttle progress emissions to every 100ms or 50KB to keep UI smooth
          if (received - lastNotifyBytes >= 50 * 1024 ||
              now.difference(lastNotifyTime).inMilliseconds >= 100) {
            lastNotifyTime = now;
            lastNotifyBytes = received;
            state = state.copyWith(
              downloadedBytes: received,
              totalBytes: total,
            );
          }
        },
      );

      _stagedPayloadDir = payloadDir;
      // Mark this update as pending so it is applied on the next start (the
      // Chrome/Firefox model) rather than swapping files under a running app.
      UpdateStaging.writePending(
        PendingUpdate(
          version: info.version.toString().replaceFirst('v', ''),
          kind: PendingUpdateKind.swap,
          sourcePath: payloadDir.path,
        ),
      );
      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        downloadedBytes: info.assetSize,
        totalBytes: info.assetSize,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: 'Failed to download update: $e',
        releaseUrl: info.htmlUrl.isNotEmpty
            ? info.htmlUrl
            : UpdateService.fallbackReleaseWebUrl,
      );
    }
  }

  /// Applies the staged update and restarts the app.
  Future<void> applyUpdateAndRestart({
    String? currentExecutablePath,
    bool preventExitForTesting = false,
  }) async {
    final payloadDir = _stagedPayloadDir;
    if (payloadDir == null || !payloadDir.existsSync()) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: 'Update payload not found. Please try downloading again.',
      );
      return;
    }

    try {
      await _service.applyUpdateAndRestart(
        payloadDir: payloadDir,
        currentExecutablePath: currentExecutablePath,
        preventExitForTesting: preventExitForTesting,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: 'Failed to apply update: $e',
      );
    }
  }
}
