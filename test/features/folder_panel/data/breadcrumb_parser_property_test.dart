import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/breadcrumb_parser.dart';
import 'package:path/path.dart' as p;

/// Property-based tests for [BreadcrumbParser].
///
/// Validates Property 7: Breadcrumb path splitting and segment navigation.
/// For any valid folder path, splitting into segments and reconstructing
/// from all segments produces an equivalent path. For any valid segment
/// index i, pathAtIndex(segments, i) is a proper prefix (or equal at last).
///
/// **Validates: Requirements 4.1, 4.2**
void main() {
  group('BreadcrumbParser property tests (Property 7)', () {
    const iterations = 150;
    final random = Random(42);
    final parser = BreadcrumbParser(p.windows);

    /// Generates a random valid Windows folder path with 1–8 segments.
    String generateWindowsPath(Random rng) {
      const driveLetters = 'CDEFGH';
      final drive = driveLetters[rng.nextInt(driveLetters.length)];
      final segmentCount = rng.nextInt(8) + 1; // 1 to 8 segments

      const folderNames = [
        'Users',
        'Music',
        'Documents',
        'Projects',
        'Albums',
        'Downloads',
        'Desktop',
        'Pictures',
        'Videos',
        'Work',
        'Data',
        'Backup',
        'Archive',
        'Temp',
        'Lib',
        'Src',
        'Build',
        'Output',
        'Assets',
        'Config',
      ];

      final segments = <String>[];
      for (var i = 0; i < segmentCount; i++) {
        segments.add(folderNames[rng.nextInt(folderNames.length)]);
      }

      return '$drive:\\${segments.join('\\')}';
    }

    test('reconstructing from all segments produces equivalent path', () {
      for (var i = 0; i < iterations; i++) {
        final path = generateWindowsPath(random);
        final segments = parser.splitSegments(path);

        expect(
          segments,
          isNotEmpty,
          reason: 'splitSegments should return non-empty for valid path: $path',
        );

        final reconstructed = parser.pathAtIndex(segments, segments.length - 1);

        // Normalize both paths for comparison (handles trailing separators).
        final normalizedOriginal = p.windows.normalize(path);
        final normalizedReconstructed = p.windows.normalize(reconstructed);

        expect(
          normalizedReconstructed,
          equals(normalizedOriginal),
          reason:
              'Reconstructed path should equal original.\n'
              '  Original: $path\n'
              '  Normalized original: $normalizedOriginal\n'
              '  Reconstructed: $reconstructed\n'
              '  Normalized reconstructed: $normalizedReconstructed\n'
              '  Segments: $segments',
        );
      }
    });

    test('pathAtIndex(segments, i) is a proper prefix for i < last index', () {
      for (var i = 0; i < iterations; i++) {
        final path = generateWindowsPath(random);
        final segments = parser.splitSegments(path);

        if (segments.length < 2) continue;

        final fullPath = p.windows.normalize(
          parser.pathAtIndex(segments, segments.length - 1),
        );

        for (var idx = 0; idx < segments.length - 1; idx++) {
          final prefix = p.windows.normalize(parser.pathAtIndex(segments, idx));

          // A proper prefix must be shorter than the full path.
          expect(
            prefix.length < fullPath.length,
            isTrue,
            reason:
                'pathAtIndex(segments, $idx) should be shorter than full path.\n'
                '  Prefix: $prefix (length ${prefix.length})\n'
                '  Full: $fullPath (length ${fullPath.length})\n'
                '  Path: $path\n'
                '  Segments: $segments',
          );

          // The full path must start with the prefix.
          expect(
            fullPath.startsWith(prefix),
            isTrue,
            reason:
                'Full path should start with pathAtIndex(segments, $idx).\n'
                '  Prefix: $prefix\n'
                '  Full: $fullPath\n'
                '  Path: $path\n'
                '  Segments: $segments',
          );
        }
      }
    });

    test('pathAtIndex at last index equals the full reconstructed path', () {
      for (var i = 0; i < iterations; i++) {
        final path = generateWindowsPath(random);
        final segments = parser.splitSegments(path);

        final lastIdx = segments.length - 1;
        final atLast = p.windows.normalize(
          parser.pathAtIndex(segments, lastIdx),
        );
        final normalizedOriginal = p.windows.normalize(path);

        expect(
          atLast,
          equals(normalizedOriginal),
          reason:
              'pathAtIndex at last index should equal original path.\n'
              '  Path: $path\n'
              '  At last index: $atLast\n'
              '  Segments: $segments',
        );
      }
    });

    test('pathAtIndex produces monotonically increasing prefixes', () {
      for (var i = 0; i < iterations; i++) {
        final path = generateWindowsPath(random);
        final segments = parser.splitSegments(path);

        String? previousPath;
        for (var idx = 0; idx < segments.length; idx++) {
          final current = p.windows.normalize(
            parser.pathAtIndex(segments, idx),
          );

          if (previousPath != null) {
            expect(
              current.length > previousPath.length,
              isTrue,
              reason:
                  'Each successive pathAtIndex should be longer.\n'
                  '  Index $idx: $current (length ${current.length})\n'
                  '  Previous: $previousPath (length ${previousPath.length})\n'
                  '  Path: $path\n'
                  '  Segments: $segments',
            );

            expect(
              current.startsWith(previousPath),
              isTrue,
              reason:
                  'Each successive pathAtIndex should start with the previous.\n'
                  '  Index $idx: $current\n'
                  '  Previous: $previousPath\n'
                  '  Path: $path\n'
                  '  Segments: $segments',
            );
          }

          previousPath = current;
        }
      }
    });
  });
}
