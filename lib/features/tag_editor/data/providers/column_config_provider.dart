import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/column_config.dart';
import '../models/column_definition.dart';

final columnConfigProvider =
    StateNotifierProvider<ColumnConfigNotifier, ColumnConfig>((ref) {
      return ColumnConfigNotifier();
    });

class ColumnConfigNotifier extends StateNotifier<ColumnConfig> {
  ColumnConfigNotifier() : super(_defaultConfig());

  static const _prefsKey = 'column_config_v1';

  /// IDs of columns that cannot be hidden or reordered from position 0.
  static const _fixedColumnIds = {'tagIndicator', 'filename'};

  /// Minimum allowed column width in logical pixels.
  static const double minColumnWidth = 40.0;

  /// Loads persisted config from SharedPreferences.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        final visible = (map['visible'] as List).cast<String>();
        final order = (map['order'] as List).cast<String>();
        // Validate: ensure fixed columns are always visible
        for (final fixed in _fixedColumnIds) {
          if (!visible.contains(fixed)) visible.insert(0, fixed);
        }

        // Load width overrides, filtering invalid entries
        final widthOverrides = <String, double>{};
        if (map['widths'] is Map) {
          final validColumnIds = defaultColumns.map((c) => c.id).toSet();
          final widthsMap = map['widths'] as Map<String, dynamic>;
          for (final entry in widthsMap.entries) {
            final value = (entry.value as num?)?.toDouble();
            if (value != null &&
                value >= minColumnWidth &&
                validColumnIds.contains(entry.key)) {
              widthOverrides[entry.key] = value;
            }
          }
        }

        state = ColumnConfig(
          visibleColumnIds: visible,
          columnOrder: order,
          widthOverrides: widthOverrides,
        );
      }
    } catch (_) {
      // On any error, keep defaults
    }
  }

  /// Toggles visibility of a column. Fixed columns cannot be hidden.
  void toggleVisibility(String columnId) {
    if (_fixedColumnIds.contains(columnId)) return;

    final visible = List<String>.from(state.visibleColumnIds);
    if (visible.contains(columnId)) {
      visible.remove(columnId);
    } else {
      // Insert at its position in columnOrder
      final orderIndex = state.columnOrder.indexOf(columnId);
      var insertAt = visible.length;
      for (var i = 0; i < visible.length; i++) {
        if (state.columnOrder.indexOf(visible[i]) > orderIndex) {
          insertAt = i;
          break;
        }
      }
      visible.insert(insertAt, columnId);
    }
    state = state.copyWith(visibleColumnIds: visible);
    _persist();
  }

  /// Reorders a column from [oldIndex] to [newIndex].
  /// Prevents tagIndicator from being moved from position 0.
  void reorderColumn(int oldIndex, int newIndex) {
    final visible = List<String>.from(state.visibleColumnIds);
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    if (newIndex < 0 || newIndex >= visible.length) return;

    // Don't allow moving fixed columns
    if (_fixedColumnIds.contains(visible[oldIndex]) && newIndex == 0) return;
    if (newIndex == 0 && visible[0] == 'tagIndicator') {
      newIndex = 1; // Can't place before tagIndicator
    }

    final item = visible.removeAt(oldIndex);
    visible.insert(newIndex, item);

    // Update full order too
    final order = List<String>.from(state.columnOrder);
    final orderOldIdx = order.indexOf(item);
    order.removeAt(orderOldIdx);
    // Find target position in order based on neighbors in visible
    final targetNeighbor = newIndex > 0 ? visible[newIndex - 1] : null;
    final orderNewIdx = targetNeighbor != null
        ? order.indexOf(targetNeighbor) + 1
        : 0;
    order.insert(orderNewIdx, item);

    state = ColumnConfig(visibleColumnIds: visible, columnOrder: order);
    _persist();
  }

  /// Moves a column from [oldIndex] to [newIndex], where [newIndex] already
  /// refers to a position in the list *after* [oldIndex] has been removed.
  ///
  /// This is the convention used by the drag-to-reorder header, which tracks
  /// the drop target while the item is still in the list. Use
  /// [reorderColumn] for the menu's Move Left / Move Right, which pass raw
  /// pre-removal indices.
  void moveColumn(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.visibleColumnIds.length) return;
    // Fixed columns must not move off the front, so the smallest reachable
    // target for a drag is index 1 when the tag indicator is present.
    final minIndex =
        state.visibleColumnIds.isNotEmpty &&
            _fixedColumnIds.contains(state.visibleColumnIds.first)
        ? 1
        : 0;
    if (newIndex < minIndex) return;
    if (newIndex >= state.visibleColumnIds.length) return;
    if (oldIndex == newIndex) return;
    reorderColumn(oldIndex, newIndex);
  }

  /// Resets to default column configuration.
  void resetToDefaults() {
    state = _defaultConfig();
    _persist();
  }

  /// Sets the width override for a single column.
  /// Clamps to [minColumnWidth, ∞). Non-resizable columns are ignored.
  void setColumnWidth(String columnId, double width) {
    if (_isNonResizable(columnId)) return;
    final clamped = width.clamp(minColumnWidth, double.infinity);
    final overrides = Map<String, double>.from(state.widthOverrides);
    overrides[columnId] = clamped;
    state = state.copyWith(widthOverrides: overrides);
  }

  /// Persists current width overrides to shared_preferences.
  /// Called on drag end, not during drag.
  Future<void> persistWidths() async => _persist();

  /// Clears all width overrides, restoring default widths.
  void resetColumnWidths() {
    state = state.copyWith(widthOverrides: {});
    _persist();
  }

  /// Returns true if the column cannot be resized.
  bool _isNonResizable(String columnId) => columnId == 'tagIndicator';

  static ColumnConfig _defaultConfig() {
    final allIds = defaultColumns.map((c) => c.id).toList();
    // Default visible set mirrors Tag&Rename's out-of-the-box columns;
    // niche Tag&Rename parity frames (rating/mood/grouping etc.) are
    // available via the header visibility toggle but hidden initially to
    // avoid overwhelming new users.
    const defaultVisible = [
      'tagIndicator',
      'filename',
      'title',
      'artist',
      'album',
      'year',
      'genre',
      'trackNumber',
      'discNumber',
      'bitrate',
      'duration',
      'albumArtist',
      'comment',
      'bpm',
      'composer',
      'conductor',
      'relativePath',
    ];
    return ColumnConfig(
      visibleColumnIds: List.from(defaultVisible),
      columnOrder: allIds,
    );
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        'visible': state.visibleColumnIds,
        'order': state.columnOrder,
      };
      if (state.widthOverrides.isNotEmpty) {
        map['widths'] = state.widthOverrides;
      }
      final json = jsonEncode(map);
      await prefs.setString(_prefsKey, json);
    } catch (_) {
      // Best-effort persistence
    }
  }
}
