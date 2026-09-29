/// Separator conventions for multi-value tag fields.
///
/// Different tools have historically written multi-value fields in different
/// ways, and a library edited by several of them can contain all of them.
/// These are the conventions actually worth recognising on read.
enum MultiValueSeparator {
  /// ID3v2.4 and later: values separated by a null byte inside one frame.
  nullByte('Null byte (0x00)'),

  /// The de-facto standard for Vorbis Comments written by desktop players,
  /// and what the grid displays: a semicolon and a space.
  semicolon('Semicolon and space ("; ")'),

  /// A bare semicolon, with no space.
  semicolonTight('Semicolon (";")'),

  /// A forward slash with surrounding spaces, common in ID3v2.3-era tags.
  slashSpaced('Slash (" / ")'),

  /// A bare forward slash.
  slashTight('Slash ("/")');

  const MultiValueSeparator(this.label);

  /// Human-readable description for the settings UI.
  final String label;

  /// The string that joins values for this convention.
  String get joiner => switch (this) {
    MultiValueSeparator.nullByte => '\u0000',
    MultiValueSeparator.semicolon => '; ',
    MultiValueSeparator.semicolonTight => ';',
    MultiValueSeparator.slashSpaced => ' / ',
    MultiValueSeparator.slashTight => '/',
  };
}

/// Tag fields that legitimately hold more than one value.
///
/// Restricted to the fields the PRD names. This is deliberately a closed
/// list: a value that happens to contain a semicolon (a comment, a title
/// like "AC/DC; Live") must not be shredded into multiple values, and the
/// only safe way to guarantee that is to opt fields in explicitly.
const multiValueFields = <String>{
  'artist',
  'albumArtist',
  'genre',
  'composer',
  'conductor',
  'lyricist',
};

/// Whether [field] supports multiple values.
bool isMultiValueField(String field) => multiValueFields.contains(field);

/// Splits a raw multi-value tag into its individual values.
///
/// Handles the null-byte convention plus the semicolon and slash
/// conventions, whichever [separator] is configured. Surrounding whitespace
/// is trimmed and empty segments are dropped, so `"Rock; ; Live"` yields two
/// values rather than three with a blank in the middle.
///
/// Returns a single-element list (or an empty one) for a field that is not a
/// multi-value field, so callers can use it unconditionally.
List<String> parseMultiValue(
  String raw,
  String field, {
  required bool splitSingleValueFields,
  MultiValueSeparator separator = MultiValueSeparator.semicolon,
  List<MultiValueSeparator>? alsoAccept,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];

  if (!isMultiValueField(field) && !splitSingleValueFields) {
    return [trimmed];
  }

  // Prefer the configured separator, but always tolerate the others: a file
  // written by another tool should not become unreadable just because this
  // install prefers a different convention.
  final separators = <String>{
    separator.joiner,
    for (final s in alsoAccept ?? MultiValueSeparator.values) s.joiner,
  };

  final parts = <String>[];
  for (final chunk in trimmed.split(_anySeparator(separators))) {
    final value = chunk.trim();
    if (value.isNotEmpty) parts.add(value);
  }

  return parts.isEmpty ? [trimmed] : parts;
}

/// Joins values back into a single string using [separator].
String formatMultiValue(
  Iterable<String> values,
  MultiValueSeparator separator,
) {
  final kept = values
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList(growable: false);
  if (kept.isEmpty) return '';
  if (kept.length == 1) return kept.single;
  return kept.join(separator.joiner);
}

/// Multi-value helpers, so a caller can read and write a field without
/// knowing which convention is in force.
class MultiValue {
  const MultiValue._();

  static List<String> parse(
    String raw,
    String field, {
    required bool splitSingleValueFields,
    MultiValueSeparator separator = MultiValueSeparator.semicolon,
  }) => parseMultiValue(
    raw,
    field,
    splitSingleValueFields: splitSingleValueFields,
    separator: separator,
  );

  static String format(
    Iterable<String> values,
    MultiValueSeparator separator,
  ) => formatMultiValue(values, separator);

  /// Adds [value] to [current] unless it is already present.
  ///
  /// Comparison is case-insensitive because "Rock" and "rock" in the same
  /// field is a data-entry accident, not two distinct genres.
  static List<String> addValue(List<String> current, String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) return List.unmodifiable(current);
    for (final existing in current) {
      if (existing.toLowerCase() == candidate.toLowerCase()) {
        return List.unmodifiable(current);
      }
    }
    return List.unmodifiable([...current, candidate]);
  }

  /// Removes [value] from [current], case-insensitively.
  static List<String> removeValue(List<String> current, String value) {
    final target = value.trim().toLowerCase();
    return List.unmodifiable(current.where((v) => v.toLowerCase() != target));
  }

  /// Replaces [from] with [to] in place, preserving position.
  ///
  /// Returns the original list unchanged when [from] is absent, so a replace
  /// across a selection of files does not rewrite files that never had the
  /// value.
  static List<String> replaceValue(
    List<String> current,
    String from,
    String to,
  ) {
    final source = from.trim().toLowerCase();
    final replacement = to.trim();
    if (replacement.isEmpty) return removeValue(current, from);
    if (!current.any((v) => v.toLowerCase() == source)) {
      return List.unmodifiable(current);
    }
    return List.unmodifiable([
      for (final v in current)
        if (v.toLowerCase() == source) replacement else v,
    ]);
  }

  /// Moves the value at [from] to [to], as a drag-and-drop reorder would.
  static List<String> reorder(List<String> current, int from, int to) {
    if (from < 0 || from >= current.length) return List.unmodifiable(current);
    if (to < 0 || to >= current.length) return List.unmodifiable(current);
    if (from == to) return List.unmodifiable(current);
    final next = [...current];
    final item = next.removeAt(from);
    next.insert(to, item);
    return List.unmodifiable(next);
  }
}

/// Builds a RegExp matching any of [separators].
///
/// The null-byte convention is matched literally; the visible separators are
/// matched with surrounding whitespace made optional so `"Rock;Live"` and
/// `"Rock; Live"` both split. Longer alternatives come first so a
/// two-character joiner is not partially consumed by a one-character one.
RegExp _anySeparator(Set<String> separators) {
  final ordered = separators.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(ordered.map(RegExp.escape).join('|'));
}
