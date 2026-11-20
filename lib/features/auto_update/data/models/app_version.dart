import '../app_version_generated.dart';

/// Semantic version representation with comparison and parsing support.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.rawTag = '',
  });

  /// The current version of Open Tag Editor.
  ///
  /// Resolved from the build-time generated constant (see
  /// `app_version_generated.dart`, generated from pubspec.yaml), because a
  /// hardcoded constant silently goes stale: the updater would then believe
  /// every published release is newer than the running build and offer
  /// updates forever (the original bug — this read 0.4.0 while 0.6.0 shipped).
  static const AppVersion current = AppVersion(
    major: AppVersionGenerated.major,
    minor: AppVersionGenerated.minor,
    patch: AppVersionGenerated.patch,
    rawTag: 'v${AppVersionGenerated.version}',
  );

  final int major;
  final int minor;
  final int patch;
  final String rawTag;

  /// Parses a version string like '0.4.1', 'v0.4.1', or 'v1.0.0-rc1'.
  static AppVersion? tryParse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1).trim();
    }

    final parts = text.split('.');
    if (parts.length < 3) return null;

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patchPart = parts[2].split('-')[0].split('+')[0];
    final patch = int.tryParse(patchPart);

    if (major == null || minor == null || patch == null) return null;

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      rawTag: raw.trim(),
    );
  }

  /// Returns true if this version is strictly newer than [other].
  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => 'v$major.$minor.$patch';
}
