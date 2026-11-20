import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/auto_update/data/app_version_generated.dart';
import 'package:open_tag_editor/features/auto_update/data/models/app_version.dart';

void main() {
  group('AppVersion parsing and comparison', () {
    test('parses standard semver strings with and without leading v', () {
      final v1 = AppVersion.tryParse('v0.4.1');
      expect(v1, isNotNull);
      expect(v1!.major, 0);
      expect(v1.minor, 4);
      expect(v1.patch, 1);

      final v2 = AppVersion.tryParse('1.2.3');
      expect(v2, isNotNull);
      expect(v2!.major, 1);
      expect(v2.minor, 2);
      expect(v2.patch, 3);

      final v3 = AppVersion.tryParse('v2.0.0-rc1+build.123');
      expect(v3, isNotNull);
      expect(v3!.major, 2);
      expect(v3.minor, 0);
      expect(v3.patch, 0);
    });

    test('returns null for malformed version strings', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('v1.2'), isNull);
      expect(AppVersion.tryParse('alpha.beta.gamma'), isNull);
      expect(AppVersion.tryParse('invalid'), isNull);
    });

    test('correctly compares version precedence', () {
      final v040 = AppVersion.tryParse('v0.4.0')!;
      final v041 = AppVersion.tryParse('v0.4.1')!;
      final v050 = AppVersion.tryParse('v0.5.0')!;
      final v100 = AppVersion.tryParse('v1.0.0')!;

      expect(v041.isNewerThan(v040), isTrue);
      expect(v050.isNewerThan(v041), isTrue);
      expect(v100.isNewerThan(v050), isTrue);

      expect(v040.isNewerThan(v041), isFalse);
      expect(v040.isNewerThan(v040), isFalse);
      expect(v040 == AppVersion.tryParse('0.4.0'), isTrue);
    });

    test('current version matches the generated build version', () {
      // Regression guard: AppVersion.current must track the real build version
      // (generated from pubspec.yaml), not a hardcoded constant that goes
      // stale. A stale value makes the updater offer every release forever.
      expect(AppVersion.current.major, AppVersionGenerated.major);
      expect(AppVersion.current.minor, AppVersionGenerated.minor);
      expect(AppVersion.current.patch, AppVersionGenerated.patch);
      expect(AppVersion.current.toString(), 'v${AppVersionGenerated.version}');
    });

    test('generated version agrees with pubspec.yaml (drift guard)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml has a version line');
      expect(
        AppVersionGenerated.version,
        match!.group(1),
        reason: 'run: dart run scripts/gen_version.dart',
      );
    });
  });
}
