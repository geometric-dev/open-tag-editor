import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// A user-pinned folder bookmark.
///
/// Stores a folder path and its display name (the last path segment).
/// Used in the Folder Panel's bookmarks section for one-click folder access.
class BookmarkEntry extends Equatable {
  const BookmarkEntry({
    required this.path,
    required this.name,
  });

  /// Creates a [BookmarkEntry] from a full folder [path], extracting the
  /// folder name from the last path segment.
  ///
  /// If the path is a root (e.g. `C:\`), the name will be the root itself.
  factory BookmarkEntry.fromPath(String path) {
    final name = p.basename(path);
    // basename returns empty string for root paths like 'C:\' — use the
    // full path as the display name in that case.
    return BookmarkEntry(
      path: path,
      name: name.isEmpty ? path : name,
    );
  }

  /// Deserializes a [BookmarkEntry] from a JSON-compatible map.
  factory BookmarkEntry.fromJson(Map<String, dynamic> json) {
    return BookmarkEntry(
      path: json['path'] as String,
      name: json['name'] as String,
    );
  }

  /// Full folder path on disk.
  final String path;

  /// Display name (last segment of path).
  final String name;

  /// Serializes this entry to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
    };
  }

  @override
  List<Object?> get props => [path];
}
