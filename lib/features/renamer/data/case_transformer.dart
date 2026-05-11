import 'models/case_option.dart';

/// Applies case transformations to resolved tag values.
class CaseTransformer {
  /// Creates a [CaseTransformer] instance.
  const CaseTransformer();

  /// Transforms [value] according to [option].
  ///
  /// If [replaceUnderscores] is true, all underscore characters are replaced
  /// with spaces before the case transformation is applied.
  String transform(
    String value, {
    required CaseOption option,
    bool replaceUnderscores = false,
  }) {
    if (value.isEmpty) return value;

    var result = value;

    if (replaceUnderscores) {
      result = result.replaceAll('_', ' ');
    }

    switch (option) {
      case CaseOption.none:
        return result;
      case CaseOption.lowercase:
        return result.toLowerCase();
      case CaseOption.uppercase:
        return result.toUpperCase();
      case CaseOption.capitalizeFirst:
        return _capitalizeFirst(result);
      case CaseOption.sentenceCase:
        return _sentenceCase(result);
    }
  }

  /// Capitalizes the first letter of each word, preserving existing spacing.
  String _capitalizeFirst(String value) {
    final buffer = StringBuffer();
    var capitalizeNext = true;

    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char.trim().isEmpty) {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// Lowercases everything, then capitalizes only the first non-whitespace
  /// character.
  String _sentenceCase(String value) {
    final lowered = value.toLowerCase();
    final buffer = StringBuffer();
    var capitalized = false;

    for (var i = 0; i < lowered.length; i++) {
      final char = lowered[i];
      if (!capitalized && char.trim().isNotEmpty) {
        buffer.write(char.toUpperCase());
        capitalized = true;
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }
}
