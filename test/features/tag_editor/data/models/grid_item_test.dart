import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/models/grid_item.dart';
import 'package:path/path.dart' as p;

/// Paths are built with [p.join] rather than hard-coded separators: the
/// implementation is platform-agnostic (it delegates to `path`), so pinning
/// the tests to `C:\` made them fail on POSIX hosts.
void main() {
  final root = p.join('C:', 'Music');
  final oneDeep = p.join(root, 'Rock');
  final twoDeep = p.join(root, 'Rock', 'Album');
  final deep = p.join(root, 'Artist', 'Year', 'Album');

  group('computeRelativePath', () {
    test('single level deep returns folder name', () {
      final result = computeRelativePath(oneDeep, root);

      expect(result, equals('Rock'));
    });

    test('multiple levels deep joins segments with space-slash-space', () {
      final result = computeRelativePath(twoDeep, root);

      expect(result, equals('Rock / Album'));
    });

    test('root folder itself returns final segment', () {
      final result = computeRelativePath(root, root);

      expect(result, equals('Music'));
    });

    test('trailing separator on root is normalised', () {
      final result = computeRelativePath(oneDeep, '$root${p.separator}');

      expect(result, equals('Rock'));
    });

    test('trailing separator on folder is normalised', () {
      final result = computeRelativePath('$oneDeep${p.separator}', root);

      expect(result, equals('Rock'));
    });

    test('deep nesting joins all segments', () {
      final result = computeRelativePath(deep, root);

      expect(result, equals('Artist / Year / Album'));
    });

    test('a folder outside the root falls back to its own name', () {
      // A rename can leave a file outside the loaded folder. `p.relative`
      // would produce `../..` segments, which are meaningless as a
      // breadcrumb; the display falls back to the folder's own name.
      final outside = p.join('C:', 'Music', 'Other');
      final result = computeRelativePath(outside, root);

      expect(result, isNot(contains('..')));
      expect(result, equals('Other'));
    });
  });
}
