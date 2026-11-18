import 'package:flutter_test/flutter_test.dart';
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

    test('current version matches project callsign v0.4.0', () {
      expect(AppVersion.current.major, 0);
      expect(AppVersion.current.minor, 4);
      expect(AppVersion.current.patch, 0);
      expect(AppVersion.current.toString(), 'v0.4.0');
    });
  });
}
