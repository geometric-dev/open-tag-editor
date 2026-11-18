import 'dart:io';

import 'app_version.dart';

/// Information about an available application release from GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.releaseNotes,
    required this.htmlUrl,
    required this.assetDownloadUrl,
    required this.assetName,
    required this.assetSize,
  });

  /// The parsed semantic version of the release.
  final AppVersion version;

  /// The raw Git tag name (e.g. 'v0.4.1').
  final String tagName;

  /// Changelog / release notes text.
  final String releaseNotes;

  /// Web link to the GitHub release page.
  final String htmlUrl;

  /// Direct download URL for the platform-specific archive.
  final String assetDownloadUrl;

  /// Filename of the platform archive.
  final String assetName;

  /// Size of the asset in bytes, or 0 if unknown.
  final int assetSize;

  /// Parses a GitHub Release JSON object into an [UpdateInfo] for the current platform.
  ///
  /// Matches platform archives created by the project's CI:
  /// - Windows: `-windows-x64.zip`
  /// - Linux: `-linux-x64.tar.gz`
  /// - macOS: `-macos-universal.tar.gz`
  static UpdateInfo? fromGitHubJson(
    Map<String, dynamic> json, {
    bool? isWindows,
    bool? isLinux,
    bool? isMacOS,
  }) {
    final tagName = json['tag_name'] as String? ?? '';
    final version = AppVersion.tryParse(tagName);
    if (version == null) return null;

    final htmlUrl =
        json['html_url'] as String? ??
        'https://github.com/geometric-dev/open-tag-editor/releases/latest';
    final body = json['body'] as String? ?? '';

    final assets = json['assets'] as List<dynamic>? ?? [];
    final win = isWindows ?? Platform.isWindows;
    final lin = isLinux ?? Platform.isLinux;
    final mac = isMacOS ?? Platform.isMacOS;

    Map<String, dynamic>? matchedAsset;

    for (final raw in assets) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String? ?? '').toLowerCase();

      if (win &&
          (name.contains('windows') ||
              name.contains('win-') ||
              name.contains('win64'))) {
        matchedAsset = raw;
        break;
      } else if (lin &&
          (name.contains('linux') ||
              name.contains('ubuntu') ||
              name.contains('debian'))) {
        matchedAsset = raw;
        break;
      } else if (mac &&
          (name.contains('macos') ||
              name.contains('darwin') ||
              name.contains('osx'))) {
        matchedAsset = raw;
        break;
      }
    }

    if (matchedAsset == null) {
      for (final raw in assets) {
        if (raw is! Map<String, dynamic>) continue;
        final name = (raw['name'] as String? ?? '').toLowerCase();
        if (win && name.endsWith('.zip')) {
          matchedAsset = raw;
          break;
        } else if ((lin || mac) &&
            (name.endsWith('.tar.gz') || name.endsWith('.tgz'))) {
          matchedAsset = raw;
          break;
        }
      }
    }

    if (matchedAsset == null) {
      // Fallback: take the first asset if present
      if (assets.isNotEmpty && assets.first is Map<String, dynamic>) {
        matchedAsset = assets.first as Map<String, dynamic>;
      }
    }

    final downloadUrl = matchedAsset?['browser_download_url'] as String? ?? '';
    final assetName = matchedAsset?['name'] as String? ?? '';
    final assetSize = (matchedAsset?['size'] as num?)?.toInt() ?? 0;

    return UpdateInfo(
      version: version,
      tagName: tagName,
      releaseNotes: body,
      htmlUrl: htmlUrl,
      assetDownloadUrl: downloadUrl,
      assetName: assetName,
      assetSize: assetSize,
    );
  }
}
