// Generates lib/features/auto_update/data/app_version_generated.dart from the
// version: line in pubspec.yaml.
//
// Run: dart run scripts/gen_version.dart
//
// Keeping the version in a generated Dart constant (rather than hardcoded in
// AppVersion) means the updater always compares against the real build
// version. A CI drift guard and a unit test both assert the generated file
// agrees with pubspec.yaml, so it cannot silently go stale again.

import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('gen_version: pubspec.yaml not found (run from repo root)');
    exit(1);
  }

  final match = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());

  if (match == null) {
    stderr.writeln('gen_version: no "version: x.y.z" line in pubspec.yaml');
    exit(1);
  }

  final version = match.group(1)!;
  final parts = version.split('.');
  final out = File('lib/features/auto_update/data/app_version_generated.dart');
  out.writeAsStringSync('''
// GENERATED FILE - do not edit by hand.
// Source of truth: the `version:` line in pubspec.yaml.
// Regenerate with: dart run scripts/gen_version.dart

/// The version of the currently running build, baked in at build time.
class AppVersionGenerated {
  const AppVersionGenerated._();

  static const String version = '$version';
  static const int major = ${parts[0]};
  static const int minor = ${parts[1]};
  static const int patch = ${parts[2]};
}
''');

  stdout.writeln('gen_version: wrote $version');
}
