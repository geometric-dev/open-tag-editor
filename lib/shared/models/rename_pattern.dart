/// A pattern used for renaming files based on tag data.
///
/// Patterns use placeholders like:
/// - `%artist%` — Artist name
/// - `%album%` — Album name
/// - `%title%` — Track title
/// - `%track%` — Track number
/// - `%year%` — Year
/// - `%genre%` — Genre
/// - `%disc%` — Disc number
///
/// Example: `%artist% - %album%/%track% - %title%`
class RenamePattern {
  const RenamePattern({required this.name, required this.pattern});

  final String name;
  final String pattern;

  /// Built-in default patterns.
  static const defaults = [
    RenamePattern(name: 'Artist - Title', pattern: '%artist% - %title%'),
    RenamePattern(name: 'Track - Title', pattern: '%track% - %title%'),
    RenamePattern(
      name: 'Artist - Album / Track - Title',
      pattern: '%artist% - %album%/%track% - %title%',
    ),
    RenamePattern(
      name: 'Track Artist - Title',
      pattern: '%track% %artist% - %title%',
    ),
    RenamePattern(
      name: 'Album / Disc-Track - Title',
      pattern: '%album%/%disc%-%track% - %title%',
    ),
  ];

  /// Applies this pattern to the given tag map, returning the new filename
  /// (without extension).
  String apply(Map<String, String> tags) {
    var result = pattern;
    final replacements = {
      '%artist%': tags['artist'] ?? '',
      '%albumartist%': tags['albumArtist'] ?? tags['artist'] ?? '',
      '%album%': tags['album'] ?? '',
      '%title%': tags['title'] ?? '',
      '%track%': (tags['trackNumber'] ?? '').padLeft(2, '0'),
      '%year%': tags['year'] ?? '',
      '%genre%': tags['genre'] ?? '',
      '%disc%': tags['discNumber'] ?? '1',
      '%comment%': tags['comment'] ?? '',
      '%composer%': tags['composer'] ?? '',
    };

    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result;
  }
}
