import 'package:open_tag_editor/features/folder_panel/data/folder_entry.dart';

/// Filters folder entries for the Quick Switcher overlay.
class QuickSwitcherFilter {
  /// Filters [entries] by case-insensitive substring match against [query].
  ///
  /// Returns entries where either the folder name or full path contains
  /// [query]. Returns all entries if [query] is empty.
  List<FolderEntry> filter(List<FolderEntry> entries, String query) {
    if (query.isEmpty) {
      return entries;
    }

    final lowerQuery = query.toLowerCase();
    return entries.where((entry) {
      return entry.name.toLowerCase().contains(lowerQuery) ||
          entry.path.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
