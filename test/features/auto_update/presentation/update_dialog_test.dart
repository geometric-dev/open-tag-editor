import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/auto_update/data/models/app_version.dart';
import 'package:open_tag_editor/features/auto_update/data/models/update_info.dart';
import 'package:open_tag_editor/features/auto_update/data/models/update_state.dart';
import 'package:open_tag_editor/features/auto_update/data/providers/update_provider.dart';
import 'package:open_tag_editor/features/auto_update/presentation/widgets/update_dialog.dart';

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

  Widget createSubject(UpdateState state) {
    return ProviderScope(
      overrides: [
        updateStateProvider.overrideWith((ref) {
          final notifier = UpdateNotifier(ref.watch(updateServiceProvider));
          // Pre-seed state
          // ignore: invalid_use_of_protected_member
          notifier.state = state;
          return notifier;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: UpdateDialog())),
    );
  }

  group('UpdateDialog widget tests', () {
    testWidgets('renders current and latest version when update is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        createSubject(
          const UpdateState(
            status: UpdateStatus.updateAvailable,
            currentVersion: currentVer,
            updateInfo: newerRelease,
          ),
        ),
      );

      expect(find.text('v0.4.0'), findsOneWidget);
      expect(find.text('v0.4.1'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Release Notes'), findsOneWidget);
    });

    testWidgets('renders Restart & Install Now when ready to install', (
      tester,
    ) async {
      await tester.pumpWidget(
        createSubject(
          const UpdateState(
            status: UpdateStatus.readyToInstall,
            currentVersion: currentVer,
            updateInfo: newerRelease,
          ),
        ),
      );

      expect(find.text('Restart & Install Now'), findsOneWidget);
    });

    testWidgets('renders error message and GitHub Release button when failed', (
      tester,
    ) async {
      await tester.pumpWidget(
        createSubject(
          const UpdateState(
            status: UpdateStatus.failed,
            currentVersion: currentVer,
            updateInfo: newerRelease,
            errorMessage: 'Network timeout during download',
            releaseUrl:
                'https://github.com/geometric-dev/open-tag-editor/releases/tag/v0.4.1',
          ),
        ),
      );

      expect(find.text('Network timeout during download'), findsOneWidget);
      expect(find.text('GitHub Release'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
