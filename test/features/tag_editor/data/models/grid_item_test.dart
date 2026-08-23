import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/models/grid_item.dart';

void main() {
  group('computeRelativePath', () {
    test('single level deep returns folder name', () {
      final result = computeRelativePath('C:\\Music\\Rock', 'C:\\Music');

      expect(result, equals('Rock'));
    });

    test('multiple levels deep joins segments with space-slash-space', () {
      final result = computeRelativePath('C:\\Music\\Rock\\Album', 'C:\\Music');

      expect(result, equals('Rock / Album'));
    });

    test('root folder itself returns final segment', () {
      final result = computeRelativePath('C:\\Music', 'C:\\Music');

      expect(result, equals('Music'));
    });

    test('trailing separator on root is normalised', () {
      final result = computeRelativePath('C:\\Music\\Rock', 'C:\\Music\\');

      expect(result, equals('Rock'));
    });

    test('trailing separator on folder is normalised', () {
      final result = computeRelativePath('C:\\Music\\Rock\\', 'C:\\Music');

      expect(result, equals('Rock'));
    });

    test('deep nesting joins all segments', () {
      final result = computeRelativePath(
        'C:\\Music\\Artist\\Year\\Album',
        'C:\\Music',
      );

      expect(result, equals('Artist / Year / Album'));
    });
  });
}
