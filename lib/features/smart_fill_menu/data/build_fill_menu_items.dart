import 'package:flutter/material.dart';

import 'build_fill_menu_label.dart';

/// Builds the list of [PopupMenuEntry] items for the smart fill menu.
///
/// Each value in [values] gets a labeled menu item. A final "blank" item
/// is always appended at the end. Labels are generated via
/// [buildFillMenuLabel] using the provided [selectedCount] and
/// [totalCount] to determine scope wording.
List<PopupMenuEntry<String>> buildFillMenuItems({
  required List<String> values,
  required int selectedCount,
  required int totalCount,
}) {
  final items = <PopupMenuEntry<String>>[];

  for (final value in values) {
    final label = buildFillMenuLabel(
      value: value,
      selectedCount: selectedCount,
      totalCount: totalCount,
    );
    items.add(
      PopupMenuItem<String>(
        value: value,
        child: Text(label),
      ),
    );
  }

  // Blank option at the end
  final blankLabel = buildFillMenuLabel(
    value: '',
    selectedCount: selectedCount,
    totalCount: totalCount,
    isBlank: true,
  );
  items.add(
    PopupMenuItem<String>(
      value: '',
      child: Text(blankLabel),
    ),
  );

  return items;
}
