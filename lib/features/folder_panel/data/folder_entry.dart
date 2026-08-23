import 'package:equatable/equatable.dart';

/// Source of a folder entry in the combined list.
enum FolderEntrySource { bookmark, recent }

/// A folder entry displayed in the Quick Switcher or Folder Panel.
///
/// Unifies bookmarks and recent folders for filtering/display.
class FolderEntry extends Equatable {
  const FolderEntry({
    required this.path,
    required this.name,
    required this.source,
  });

  /// Full folder path.
  final String path;

  /// Display name (folder name extracted from path).
  final String name;

  /// Whether this entry comes from bookmarks or recent history.
  final FolderEntrySource source;

  @override
  List<Object?> get props => [path, source];
}
