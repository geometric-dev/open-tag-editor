import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/auto_update/data/models/app_version.dart';
import 'package:open_tag_editor/features/auto_update/data/models/update_info.dart';
import 'package:open_tag_editor/features/auto_update/data/models/update_state.dart';
import 'package:open_tag_editor/features/auto_update/data/providers/update_provider.dart';
import 'package:open_tag_editor/features/auto_update/data/services/update_service.dart';

class FakeUpdateService extends UpdateService {
  FakeUpdateService({
    this.releaseToReturn,
    this.throwOnCheck = false,
    this.throwOnDownload = false,
  });

  final UpdateInfo? releaseToReturn;
  final bool throwOnCheck;
  final bool throwOnDownload;

  bool downloadCalled = false;
  bool restartCalled = false;

  @override
  Future<UpdateInfo?> fetchLatestRelease() async {
    if (throwOnCheck) {
      throw const HttpException('Simulated GitHub API rate limit error');
    }
    return releaseToReturn;
  }

  @override
  Future<Directory> downloadAndStageUpdate(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    Directory? customStagingDir,
  }) async {
    downloadCalled = true;
    if (throwOnDownload) {
      throw const SocketException('Connection failed');
    }
    onProgress?.call(100, 100);
    final temp = Directory.systemTemp.createTempSync('fake_staged_');
    return temp;
  }

  @override
  Future<void> applyUpdateAndRestart({
    required Directory payloadDir,
    String? currentExecutablePath,
    bool preventExitForTesting = false,
  }) async {
    restartCalled = true;
  }
}

void main() {
  const currentVer = AppVersion(major: 0, minor: 4, patch: 0);

  const newerRelease = UpdateInfo(
    version: AppVersion(major: 0, minor: 4, patch: 1),
    tagName: 'v0.4.1',
    releaseNotes: 'Fixed bug, added features',
    htmlUrl:
        'https://github.com/geometric-dev/open-tag-editor/releases/tag/v0.4.1',
    assetDownloadUrl: 'https://github.com/downloads/v0.4.1.zip',
    assetName: 'open_tag_editor-0.4.1-windows-x64.zip',
    assetSize: 1024,
  );

  group('UpdateNotifier state machine', () {
    test(
      'transitions to updateAvailable when a newer release is published',
      () async {
        final service = FakeUpdateService(releaseToReturn: newerRelease);
        final notifier = UpdateNotifier(service, currentVersion: currentVer);

        expect(notifier.state.status, UpdateStatus.idle);
        await notifier.checkForUpdate(autoDownload: false);

        expect(notifier.state.status, UpdateStatus.updateAvailable);
        expect(notifier.state.updateInfo?.version.toString(), 'v0.4.1');
        expect(notifier.state.releaseUrl, newerRelease.htmlUrl);
      },
    );

    test(
      'transitions to upToDate when latest release matches or is older',
      () async {
        const olderRelease = UpdateInfo(
          version: AppVersion(major: 0, minor: 4, patch: 0),
          tagName: 'v0.4.0',
          releaseNotes: 'Old release',
          htmlUrl: 'https://github.com/releases/v0.4.0',
          assetDownloadUrl: 'https://github.com/downloads/v0.4.0.zip',
          assetName: 'file.zip',
          assetSize: 1024,
        );

        final service = FakeUpdateService(releaseToReturn: olderRelease);
        final notifier = UpdateNotifier(service, currentVersion: currentVer);

        await notifier.checkForUpdate(autoDownload: false);
        expect(notifier.state.status, UpdateStatus.upToDate);
      },
    );

    test(
      'automatically downloads and stages update when autoDownload is true',
      () async {
        final service = FakeUpdateService(releaseToReturn: newerRelease);
        final notifier = UpdateNotifier(service, currentVersion: currentVer);

        await notifier.checkForUpdate(autoDownload: true);
        expect(service.downloadCalled, isTrue);
        expect(notifier.state.status, UpdateStatus.readyToInstall);
        expect(notifier.stagedPayloadDir, isNotNull);

        // Verify restart swap call
        await notifier.applyUpdateAndRestart(preventExitForTesting: true);
        expect(service.restartCalled, isTrue);

        if (notifier.stagedPayloadDir?.existsSync() == true) {
          notifier.stagedPayloadDir!.deleteSync(recursive: true);
        }
      },
    );

    test(
      'sets status failed with GitHub release URL fallback when download fails',
      () async {
        final service = FakeUpdateService(
          releaseToReturn: newerRelease,
          throwOnDownload: true,
        );
        final notifier = UpdateNotifier(service, currentVersion: currentVer);

        await notifier.checkForUpdate(autoDownload: true);
        expect(notifier.state.status, UpdateStatus.failed);
        expect(
          notifier.state.errorMessage,
          contains('Failed to download update'),
        );
        expect(notifier.state.releaseUrl, newerRelease.htmlUrl);
      },
    );

    test('sets status failed with fallback URL when check fails', () async {
      final service = FakeUpdateService(throwOnCheck: true);
      final notifier = UpdateNotifier(service, currentVersion: currentVer);

      await notifier.checkForUpdate();
      expect(notifier.state.status, UpdateStatus.failed);
      expect(
        notifier.state.errorMessage,
        contains('Simulated GitHub API rate limit'),
      );
      expect(notifier.state.releaseUrl, UpdateService.fallbackReleaseWebUrl);
    });
  });
}
