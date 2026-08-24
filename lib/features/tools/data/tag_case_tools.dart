import '../../../../shared/models/audio_file.dart';

/// The tag-field transforms offered in the Tools menu.
enum TagTool {
  /// "The Beatles" -> "Beatles, The"
  artistTheToComma('Format "The Artist" to "Artist, The"'),

  /// "Beatles, The" -> "The Beatles"
  artistCommaToThe('Format "Artist, The" to "The Artist"');

  const TagTool(this.menuLabel);

  final String menuLabel;

  /// Fields this tool applies to.
  List<String> get targetFields => const ['artist', 'albumArtist'];
}

/// Applies [tool] to [file], returning the per-field delta (only fields
/// whose value actually changed). Empty map when nothing would change.
Map<String, String> applyTool(TagTool tool, AudioFile file) {
  final delta = <String, String>{};
  for (final field in tool.targetFields) {
    final current = file.tags[field];
    if (current == null || current.isEmpty) continue;

    final transformed = switch (tool) {
      TagTool.artistTheToComma => theToComma(current),
      TagTool.artistCommaToThe => commaToThe(current),
    };
    if (transformed != current) {
      delta[field] = transformed;
    }
  }
  return delta;
}

/// Moves a leading article to a trailing ", The/An/A": `The Beatles` →
/// `Beatles, The`. Case-preserving for the article itself.
String theToComma(String input) {
  final match = RegExp(r'^(\s*)(The|An|A)(\s+)(.+)$', caseSensitive: false)
      .firstMatch(input);
  if (match == null) return input;
  return '${match.group(4)}, ${match.group(2)}';
}

/// Inverse of [theToComma]: `Beatles, The` → `The Beatles`.
String commaToThe(String input) {
  final match =
      RegExp(r'^(.+),\s*(The|An|A)$', caseSensitive: false).firstMatch(input);
  if (match == null) return input;
  return '${match.group(2)} ${match.group(1)}';
}
