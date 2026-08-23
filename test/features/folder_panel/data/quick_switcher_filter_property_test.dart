import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/folder_entry.dart';
import 'package:open_tag_editor/features/folder_panel/data/quick_switcher_filter.dart';

/// **Validates: Requirements 5.2**
///
/// Property 8: Quick Switcher filter correctness
///
/// For any list of folder entries and any non-empty query string, every entry
/// in the filtered results SHALL contain the query as a case-insensitive
/// substring (in either the name or path), and every entry excluded from
/// results SHALL NOT contain the query as a case-insensitive substring in
/// either field.
void main() {
  group('QuickSwitcherFilter - Property 8: filter correctness', () {
    late QuickSwitcherFilter filter;
    late Random random;

    setUp(() {
      filter = QuickSwitcherFilter();
      random = Random(42);
    });

    String randomString(Random rng, int minLen, int maxLen) {
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- ';
      final length = minLen + rng.nextInt(maxLen - minLen + 1);
      return String.fromCharCodes(
        List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
      );
    }

    String randomPath(Random rng) {
      final drive = String.fromCharCode(65 + rng.nextInt(4)); // A-D
      final segmentCount = 1 + rng.nextInt(5);
      final segments = List.generate(segmentCount, (_) => randomString(rng, 2, 10));
      return '$drive:\\${segments.join('\\')}';
    }

    FolderEntry randomEntry(Random rng) {
      final path = randomPath(rng);
      final name = randomString(rng, 2, 12);
      final source = rng.nextBool()
          ? FolderEntrySource.bookmark
          : FolderEntrySource.recent;
      return FolderEntry(path: path, name: name, source: source);
    }

    String randomQuery(Random rng, List<FolderEntry> entries) {
      // Mix of strategies: sometimes pick a substring from an entry,
      // sometimes generate a fully random query.
      if (entries.isNotEmpty && rng.nextBool()) {
        // Pick a substring from a random entry's name or path.
        final entry = entries[rng.nextInt(entries.length)];
        final source = rng.nextBool() ? entry.name : entry.path;
        if (source.length >= 2) {
          final start = rng.nextInt(source.length - 1);
          final end = start + 1 + rng.nextInt(source.length - start - 1);
          return source.substring(start, end);
        }
      }
      // Fallback: random short string (may or may not match).
      return randomString(rng, 1, 5);
    }

    test('included entries contain query, excluded entries do not (100 iterations)', () {
      for (var i = 0; i < 100; i++) {
        final entryCount = random.nextInt(20);
        final entries = List.generate(entryCount, (_) => randomEntry(random));
        final query = randomQuery(random, entries);

        // Skip empty queries — property is defined for non-empty queries.
        if (query.isEmpty) continue;

        final results = filter.filter(entries, query);
        final lowerQuery = query.toLowerCase();

        // Every included entry must contain the query in name or path.
        for (final entry in results) {
          final nameContains = entry.name.toLowerCase().contains(lowerQuery);
          final pathContains = entry.path.toLowerCase().contains(lowerQuery);
          expect(
            nameContains || pathContains,
            isTrue,
            reason: 'Included entry "${entry.name}" (path: "${entry.path}") '
                'does not contain query "$query" (iteration $i)',
          );
        }

        // Every excluded entry must NOT contain the query in name or path.
        final excluded = entries.where((e) => !results.contains(e));
        for (final entry in excluded) {
          final nameContains = entry.name.toLowerCase().contains(lowerQuery);
          final pathContains = entry.path.toLowerCase().contains(lowerQuery);
          expect(
            nameContains || pathContains,
            isFalse,
            reason: 'Excluded entry "${entry.name}" (path: "${entry.path}") '
                'contains query "$query" but was excluded (iteration $i)',
          );
        }
      }
    });
  });
}
