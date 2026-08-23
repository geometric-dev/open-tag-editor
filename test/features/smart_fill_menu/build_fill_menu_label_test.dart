import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/smart_fill_menu/data/build_fill_menu_label.dart';

void main() {
  final random = Random(42);

  String randomString(int length) {
    return String.fromCharCodes(
      List.generate(length, (_) => 0x41 + random.nextInt(26)),
    );
  }

  // Feature: smart-fill-menu, Property 2: buildFillMenuLabel scope determination
  // **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 7.3, 7.4, 7.5**
  group('Property 2: buildFillMenuLabel scope determination', () {
    test('label contains "all" iff selectedCount == 0 or selectedCount == totalCount', () {
      for (var i = 0; i < 100; i++) {
        final totalCount = 1 + random.nextInt(50);
        final selectedCount = random.nextInt(totalCount + 1);
        final value = randomString(1 + random.nextInt(30));

        final label = buildFillMenuLabel(
          value: value,
          selectedCount: selectedCount,
          totalCount: totalCount,
        );

        final isAllScope = selectedCount == 0 || selectedCount == totalCount;

        if (isAllScope) {
          expect(
            label.contains('all'),
            isTrue,
            reason: 'Expected "all" in label when selectedCount=$selectedCount, '
                'totalCount=$totalCount, but got: $label',
          );
          expect(
            label.contains('selected'),
            isFalse,
            reason: 'Expected no "selected" in label when selectedCount=$selectedCount, '
                'totalCount=$totalCount, but got: $label',
          );
        }
      }
    });

    test('label contains "selected" iff 0 < selectedCount < totalCount', () {
      for (var i = 0; i < 100; i++) {
        final totalCount = 2 + random.nextInt(50);
        final selectedCount = 1 + random.nextInt(totalCount - 1);
        final value = randomString(1 + random.nextInt(30));

        final label = buildFillMenuLabel(
          value: value,
          selectedCount: selectedCount,
          totalCount: totalCount,
        );

        expect(
          label.contains('selected'),
          isTrue,
          reason: 'Expected "selected" in label when selectedCount=$selectedCount, '
              'totalCount=$totalCount, but got: $label',
        );
        expect(
          label.contains('all'),
          isFalse,
          reason: 'Expected no "all" in label when selectedCount=$selectedCount, '
              'totalCount=$totalCount, but got: $label',
        );
      }
    });

    test('when isBlank is true, label ends with "blank"', () {
      for (var i = 0; i < 100; i++) {
        final totalCount = 1 + random.nextInt(50);
        final selectedCount = random.nextInt(totalCount + 1);
        final value = randomString(random.nextInt(50));

        final label = buildFillMenuLabel(
          value: value,
          selectedCount: selectedCount,
          totalCount: totalCount,
          isBlank: true,
        );

        expect(
          label.endsWith('blank'),
          isTrue,
          reason: 'Expected label to end with "blank" when isBlank=true, '
              'but got: $label',
        );
      }
    });
  });

  // Feature: smart-fill-menu, Property 3: buildFillMenuLabel truncation
  // **Validates: Requirements 3.6**
  group('Property 3: buildFillMenuLabel truncation', () {
    test('values longer than 40 chars are truncated with ellipsis', () {
      for (var i = 0; i < 100; i++) {
        final length = 41 + random.nextInt(160);
        final str = randomString(length);

        final label = buildFillMenuLabel(
          value: str,
          selectedCount: 0,
          totalCount: 1,
        );

        final expectedTruncated = '${str.substring(0, 40)}\u2026';
        expect(
          label.contains(expectedTruncated),
          isTrue,
          reason: 'Expected label to contain truncated value '
              '"${str.substring(0, 40)}…" for string of length $length, '
              'but got: $label',
        );
      }
    });

    test('values of 40 chars or fewer are not truncated', () {
      for (var i = 0; i < 100; i++) {
        final length = 1 + random.nextInt(40);
        final str = randomString(length);

        final label = buildFillMenuLabel(
          value: str,
          selectedCount: 0,
          totalCount: 1,
        );

        expect(
          label.contains(str),
          isTrue,
          reason: 'Expected label to contain original value "$str" '
              'for string of length $length, but got: $label',
        );
        expect(
          label.contains('\u2026'),
          isFalse,
          reason: 'Expected no ellipsis in label for string of length $length, '
              'but got: $label',
        );
      }
    });

    test('empty string value is handled correctly (no truncation)', () {
      // Edge case: empty string with isBlank=false
      final label = buildFillMenuLabel(
        value: '',
        selectedCount: 0,
        totalCount: 1,
      );

      expect(
        label.contains('\u2026'),
        isFalse,
        reason: 'Expected no ellipsis for empty string, but got: $label',
      );
    });
  });
}
