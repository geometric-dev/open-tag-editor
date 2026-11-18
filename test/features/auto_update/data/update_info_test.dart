import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/auto_update/data/models/update_info.dart';

void main() {
  group('UpdateInfo.fromGitHubJson', () {
    final mockReleaseJson = {
      'tag_name': 'v0.4.1',
      'html_url':
          'https://github.com/geometric-dev/open-tag-editor/releases/tag/v0.4.1',
      'body': '## [0.4.1]\n- Added auto-update check\n- Progressive loading',
      'assets': [
        {
          'name': 'open_tag_editor-0.4.1-windows-x64.zip',
          'browser_download_url':
              'https://github.com/geometric-dev/open-tag-editor/releases/download/v0.4.1/open_tag_editor-0.4.1-windows-x64.zip',
          'size': 42000000,
        },
        {
          'name': 'open_tag_editor-0.4.1-linux-x64.tar.gz',
          'browser_download_url':
              'https://github.com/geometric-dev/open-tag-editor/releases/download/v0.4.1/open_tag_editor-0.4.1-linux-x64.tar.gz',
          'size': 40000000,
        },
        {
          'name': 'open_tag_editor-0.4.1-macos-universal.tar.gz',
          'browser_download_url':
              'https://github.com/geometric-dev/open-tag-editor/releases/download/v0.4.1/open_tag_editor-0.4.1-macos-universal.tar.gz',
          'size': 45000000,
        },
      ],
    };

    test('correctly resolves Windows asset on Windows', () {
      final info = UpdateInfo.fromGitHubJson(
        mockReleaseJson,
        isWindows: true,
        isLinux: false,
        isMacOS: false,
      );

      expect(info, isNotNull);
      expect(info!.version.toString(), 'v0.4.1');
      expect(info.tagName, 'v0.4.1');
      expect(info.assetName, 'open_tag_editor-0.4.1-windows-x64.zip');
      expect(info.assetSize, 42000000);
      expect(
        info.htmlUrl,
        'https://github.com/geometric-dev/open-tag-editor/releases/tag/v0.4.1',
      );
      expect(info.releaseNotes, contains('Progressive loading'));
    });

    test('correctly resolves Linux asset on Linux', () {
      final info = UpdateInfo.fromGitHubJson(
        mockReleaseJson,
        isWindows: false,
        isLinux: true,
        isMacOS: false,
      );

      expect(info, isNotNull);
      expect(info!.assetName, 'open_tag_editor-0.4.1-linux-x64.tar.gz');
      expect(info.assetSize, 40000000);
    });

    test('correctly resolves macOS asset on macOS', () {
      final info = UpdateInfo.fromGitHubJson(
        mockReleaseJson,
        isWindows: false,
        isLinux: false,
        isMacOS: true,
      );

      expect(info, isNotNull);
      expect(info!.assetName, 'open_tag_editor-0.4.1-macos-universal.tar.gz');
      expect(info.assetSize, 45000000);
    });

    test('returns null if tag_name cannot be parsed into a SemVer', () {
      final invalidJson = {
        'tag_name': 'not-a-version',
        'html_url': 'https://example.com',
        'assets': [],
      };

      final info = UpdateInfo.fromGitHubJson(invalidJson);
      expect(info, isNull);
    });
  });
}
