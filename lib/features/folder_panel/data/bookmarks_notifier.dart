import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:open_tag_editor/features/folder_panel/data/bookmark_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the bookmarks list.
final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, List<BookmarkEntry>>((ref) {
  return BookmarksNotifier();
});

/// Manages user-pinned folder bookmarks with persistence via SharedPreferences.
///
/// Bookmarks are user-curated, reorderable, and capped at [maxBookmarks].
/// Persistence is best-effort — in-memory state remains correct even if
/// SharedPreferences writes fail.
class BookmarksNotifier extends StateNotifier<List<BookmarkEntry>> {
  /// Creates a [BookmarksNotifier] with an empty initial state.
  BookmarksNotifier() : super([]);

  static const _prefsKey = 'bookmarks_v1';

  /// Maximum number of bookmarks allowed.
  static const maxBookmarks = 50;

  /// Loads bookmarks from SharedPreferences.
  ///
  /// On error or corrupt data, initializes with an empty list.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final list = (jsonDecode(json) as List)
            .cast<Map<String, dynamic>>()
            .map(BookmarkEntry.fromJson)
            .toList();
        state = list;
      }
    } catch (_) {
      // On error, keep empty list
    }
  }

  /// Adds a folder [path] to the end of the bookmarks list.
  ///
  /// No-op if [path] already exists in bookmarks (idempotent) or if the
  /// list is at [maxBookmarks] capacity.
  void addBookmark(String path) {
    if (state.length >= maxBookmarks) return;
    if (state.any((entry) => entry.path == path)) return;
    state = [...state, BookmarkEntry.fromPath(path)];
    _persist();
  }

  /// Removes a bookmark by [path].
  ///
  /// No-op if the path is not in the bookmarks list.
  void removeBookmark(String path) {
    final updated = state.where((entry) => entry.path != path).toList();
    if (updated.length == state.length) return;
    state = updated;
    _persist();
  }

  /// Reorders a bookmark from [oldIndex] to [newIndex].
  ///
  /// Uses the standard Flutter reorderable list convention where [newIndex]
  /// is adjusted if it comes after [oldIndex].
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.length) return;
    var adjustedNewIndex = newIndex;
    if (adjustedNewIndex > oldIndex) {
      adjustedNewIndex--;
    }
    if (adjustedNewIndex < 0 || adjustedNewIndex >= state.length) return;
    if (oldIndex == adjustedNewIndex) return;
    final updated = [...state];
    final item = updated.removeAt(oldIndex);
    updated.insert(adjustedNewIndex, item);
    state = updated;
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, json);
    } catch (_) {
      // Best-effort persistence
    }
  }
}
