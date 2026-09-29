import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/column_width_resolver.dart';
import 'package:open_tag_editor/features/tag_editor/data/models/column_definition.dart';

void main() {
  group('resolveEffectiveWidth', () {
    final columns = [
      const ColumnDefinition(id: 'title', label: 'Title', defaultWidth: 150),
      const ColumnDefinition(id: 'artist', label: 'Artist', defaultWidth: 120),
      const ColumnDefinition(id: 'album', label: 'Album', defaultWidth: 180),
    ];

    test('column with override returns override value', () {
      final overrides = {'title': 250.0, 'artist': 90.0};

      expect(resolveEffectiveWidth('title', overrides, columns), 250.0);
      expect(resolveEffectiveWidth('artist', overrides, columns), 90.0);
    });

    test('column without override returns defaultWidth', () {
      final overrides = {'title': 250.0};

      expect(resolveEffectiveWidth('artist', overrides, columns), 120.0);
      expect(resolveEffectiveWidth('album', overrides, columns), 180.0);
    });

    test('unknown column ID falls back to defaultWidth of first column', () {
      final overrides = <String, double>{};

      expect(resolveEffectiveWidth('nonexistent', overrides, columns), 150.0);
    });

    test('empty overrides map returns defaultWidth for all columns', () {
      final overrides = <String, double>{};

      expect(resolveEffectiveWidth('title', overrides, columns), 150.0);
      expect(resolveEffectiveWidth('artist', overrides, columns), 120.0);
      expect(resolveEffectiveWidth('album', overrides, columns), 180.0);
    });
  });

  group('calculateAutoFitWidth', () {
    test('empty cell list returns header width + padding clamped to min', () {
      final result = calculateAutoFitWidth(
        cellWidths: [],
        headerLabelWidth: 30.0,
      );

      // max(30.0, ...empty) = 30.0; 30.0 + 16.0 = 46.0; clamp(40, 500) = 46.0
      expect(result, 46.0);
    });

    test('empty cell list with small header clamps to min', () {
      final result = calculateAutoFitWidth(
        cellWidths: [],
        headerLabelWidth: 10.0,
      );

      // max(10.0) = 10.0; 10.0 + 16.0 = 26.0; clamp(40, 500) = 40.0
      expect(result, 40.0);
    });

    test('single cell wider than max returns max (500.0)', () {
      final result = calculateAutoFitWidth(
        cellWidths: [600.0],
        headerLabelWidth: 50.0,
      );

      // max(50.0, 600.0) = 600.0; 600.0 + 16.0 = 616.0; clamp(40, 500) = 500.0
      expect(result, 500.0);
    });

    test('all cells narrower than min returns min (40.0)', () {
      final result = calculateAutoFitWidth(
        cellWidths: [5.0, 10.0, 8.0],
        headerLabelWidth: 12.0,
      );

      // max(12.0, 5.0, 10.0, 8.0) = 12.0; 12.0 + 16.0 = 28.0; clamp(40, 500) = 40.0
      expect(result, 40.0);
    });

    test('header wider than all cells uses header width', () {
      final result = calculateAutoFitWidth(
        cellWidths: [30.0, 40.0, 35.0],
        headerLabelWidth: 80.0,
      );

      // max(80.0, 30.0, 40.0, 35.0) = 80.0; 80.0 + 16.0 = 96.0; clamp(40, 500) = 96.0
      expect(result, 96.0);
    });

    test('normal case returns max cell width + padding', () {
      final result = calculateAutoFitWidth(
        cellWidths: [100.0, 200.0, 150.0],
        headerLabelWidth: 60.0,
      );

      // max(60.0, 100.0, 200.0, 150.0) = 200.0; 200.0 + 16.0 = 216.0; clamp(40, 500) = 216.0
      expect(result, 216.0);
    });

    test('custom padding is applied correctly', () {
      final result = calculateAutoFitWidth(
        cellWidths: [100.0],
        headerLabelWidth: 50.0,
        padding: 24.0,
      );

      // max(50.0, 100.0) = 100.0; 100.0 + 24.0 = 124.0; clamp(40, 500) = 124.0
      expect(result, 124.0);
    });

    test('custom min and max are respected', () {
      final result = calculateAutoFitWidth(
        cellWidths: [100.0],
        headerLabelWidth: 50.0,
        minWidth: 60.0,
        maxWidth: 110.0,
      );

      // max(50.0, 100.0) = 100.0; 100.0 + 16.0 = 116.0; clamp(60, 110) = 110.0
      expect(result, 110.0);
    });
  });
}
