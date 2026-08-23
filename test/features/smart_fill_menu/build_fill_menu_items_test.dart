import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/smart_fill_menu/data/build_fill_menu_items.dart';

/// Property-based tests for buildFillMenuItems.
///
/// Each property is tested with 100+ random inputs to verify the invariant
/// holds across the input space.
void main() {
  final random = Random(42);

  /// Generates a random string of [length] using uppercase ASCII letters.
  String randomString(int length) {
    return String.fromCharCodes(
      List.generate(length, (_) => 0x41 + random.nextInt(26)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Feature: smart-fill-menu, Property 4: buildFillMenuItems blank-last
  // invariant
  // ─────────────────────────────────────────────────────────────────────────

  // **Validates: Requirements 2.3, 2.5**

  group('Property 4: buildFillMenuItems blank-last invariant', () {
    test(
      'last entry is blank option and preceding entries match input values in order',
      () {
        for (var i = 0; i < 100; i++) {
          final valueCount = random.nextInt(61); // 0–60
          final values = List.generate(
            valueCount,
            (_) => randomString(1 + random.nextInt(30)),
          );
          final totalCount = 1 + random.nextInt(50);
          final selectedCount = random.nextInt(totalCount + 1);

          final items = buildFillMenuItems(
            values: values,
            selectedCount: selectedCount,
            totalCount: totalCount,
          );

          // Total items = values + 1 blank
          expect(
            items.length,
            equals(values.length + 1),
            reason: 'Expected ${values.length + 1} items '
                '(${values.length} values + 1 blank) but got ${items.length} '
                '(iteration $i)',
          );

          // Last item is blank
          final lastItem = items.last as PopupMenuItem<String>;
          expect(
            lastItem.value,
            equals(''),
            reason: 'Last item must be the blank option with empty string '
                'value, but got "${lastItem.value}" (iteration $i)',
          );

          // Preceding items match input values in order
          for (var j = 0; j < values.length; j++) {
            final item = items[j] as PopupMenuItem<String>;
            expect(
              item.value,
              equals(values[j]),
              reason: 'Item at index $j should have value "${values[j]}" '
                  'but got "${item.value}" (iteration $i)',
            );
          }
        }
      },
    );
  });
}
