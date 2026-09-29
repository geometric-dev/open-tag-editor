import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/breadcrumb_parser.dart';
import 'package:path/path.dart' as p;

void main() {
  group('BreadcrumbParser (Windows)', () {
    late BreadcrumbParser parser;

    setUp(() {
      parser = BreadcrumbParser(p.windows);
    });

    group('splitSegments', () {
      test('returns empty list for empty string', () {
        expect(parser.splitSegments(''), isEmpty);
      });

      test('splits drive root into single segment', () {
        expect(parser.splitSegments(r'C:\'), ['C:\\']);
      });

      test('splits path with drive letter into segments', () {
        expect(parser.splitSegments(r'C:\Users\Music'), [
          'C:\\',
          'Users',
          'Music',
        ]);
      });

      test('splits deep path into segments', () {
        expect(
          parser.splitSegments(r'D:\Projects\Flutter\open_tag_editor\lib'),
          ['D:\\', 'Projects', 'Flutter', 'open_tag_editor', 'lib'],
        );
      });

      test('handles trailing separator', () {
        expect(parser.splitSegments(r'C:\Users\Music\'), [
          'C:\\',
          'Users',
          'Music',
        ]);
      });

      test('handles single folder under drive', () {
        expect(parser.splitSegments(r'C:\Users'), ['C:\\', 'Users']);
      });
    });

    group('pathAtIndex', () {
      test('returns empty string for empty segments', () {
        expect(parser.pathAtIndex([], 0), '');
      });

      test('returns empty string for negative index', () {
        expect(parser.pathAtIndex(['C:\\', 'Users'], -1), '');
      });

      test('returns empty string for out-of-bounds index', () {
        expect(parser.pathAtIndex(['C:\\', 'Users'], 5), '');
      });

      test('returns drive root for index 0', () {
        final segments = parser.splitSegments(r'C:\Users\Music');
        expect(parser.pathAtIndex(segments, 0), r'C:\');
      });

      test('returns partial path for intermediate index', () {
        final segments = parser.splitSegments(r'C:\Users\Music\Albums');
        expect(parser.pathAtIndex(segments, 1), r'C:\Users');
        expect(parser.pathAtIndex(segments, 2), r'C:\Users\Music');
      });

      test('returns full path for last index', () {
        final segments = parser.splitSegments(r'C:\Users\Music');
        expect(
          parser.pathAtIndex(segments, segments.length - 1),
          r'C:\Users\Music',
        );
      });
    });
  });

  group('BreadcrumbParser (POSIX)', () {
    late BreadcrumbParser parser;

    setUp(() {
      parser = BreadcrumbParser(p.posix);
    });

    group('splitSegments', () {
      test('returns empty list for empty string', () {
        expect(parser.splitSegments(''), isEmpty);
      });

      test('splits root into single segment', () {
        expect(parser.splitSegments('/'), ['/']);
      });

      test('splits path into segments', () {
        expect(parser.splitSegments('/home/user/music'), [
          '/',
          'home',
          'user',
          'music',
        ]);
      });

      test('handles trailing separator', () {
        expect(parser.splitSegments('/home/user/music/'), [
          '/',
          'home',
          'user',
          'music',
        ]);
      });
    });

    group('pathAtIndex', () {
      test('returns root for index 0', () {
        final segments = parser.splitSegments('/home/user/music');
        expect(parser.pathAtIndex(segments, 0), '/');
      });

      test('returns partial path for intermediate index', () {
        final segments = parser.splitSegments('/home/user/music');
        expect(parser.pathAtIndex(segments, 1), '/home');
        expect(parser.pathAtIndex(segments, 2), '/home/user');
      });

      test('returns full path for last index', () {
        final segments = parser.splitSegments('/home/user/music');
        expect(
          parser.pathAtIndex(segments, segments.length - 1),
          '/home/user/music',
        );
      });
    });
  });
}
