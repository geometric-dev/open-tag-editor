import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/theme/app_theme.dart';

void main() {
  group('high contrast themes', () {
    test('light: surface is pure white and onSurface is pure black', () {
      final scheme = AppTheme.highContrastLight.colorScheme;

      expect(scheme.brightness, Brightness.light);
      expect(scheme.surface, Colors.white);
      expect(scheme.onSurface, Colors.black);
    });

    test('dark: surface is pure black and onSurface is pure white', () {
      final scheme = AppTheme.highContrastDark.colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.surface, Colors.black);
      expect(scheme.onSurface, Colors.white);
    });

    test('surface and onSurface are maximally different', () {
      for (final theme in [
        AppTheme.highContrastLight,
        AppTheme.highContrastDark,
      ]) {
        final scheme = theme.colorScheme;
        // computeLuminance 0 vs 1 is the largest possible separation.
        expect(
          (scheme.onSurface.computeLuminance() -
                  scheme.surface.computeLuminance())
              .abs(),
          closeTo(1.0, 0.01),
          reason: 'surface and foreground must be at opposite extremes',
        );
      }
    });

    test('dividers are heavier than in the default theme', () {
      final hc = AppTheme.highContrastLight.dividerTheme;
      final standard = AppTheme.light.dividerTheme;

      expect(hc.thickness, greaterThan(standard.thickness!));
      expect(hc.color, AppTheme.highContrastLight.colorScheme.outline);
    });

    test('the default themes are left alone', () {
      // The high-contrast option must be opt-in, not a change of baseline.
      expect(AppTheme.light.colorScheme.surface, isNot(Colors.white));
      expect(AppTheme.light.dividerTheme.thickness, 1);
      expect(AppTheme.dark.dividerTheme.thickness, 1);
    });

    test('the primary seed colour is still recognisable', () {
      // A high-contrast scheme that also changes the brand hue would be a
      // bigger change than the setting promises.
      for (final theme in [AppTheme.light, AppTheme.highContrastLight]) {
        expect(theme.colorScheme.primary, AppTheme.light.colorScheme.primary);
      }
    });
  });
}
