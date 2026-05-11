import '../../renamer/data/models/mask_token.dart';
import 'models/extraction_result.dart';

/// Extracts tag values from a file path by matching it against parsed mask
/// tokens.
///
/// This is the inverse of [MaskEvaluator] — instead of building a filename
/// from tags, it decomposes a filename into tag values using the mask's
/// literal delimiters as split points.
class MaskExtractor {
  /// Creates a [MaskExtractor] instance.
  const MaskExtractor();

  /// Validates that a token list is suitable for extraction.
  ///
  /// Returns `null` if valid, or an error message if invalid.
  /// Extraction requires that no two variable/ignore tokens are adjacent
  /// without a literal token between them.
  String? validateForExtraction(List<MaskToken> tokens) {
    if (tokens.isEmpty) return null;

    for (var i = 0; i < tokens.length - 1; i++) {
      final current = tokens[i];
      final next = tokens[i + 1];

      if (_isVariableOrIgnore(current) && _isVariableOrIgnore(next)) {
        final currentName = _tokenDisplayName(current);
        final nextName = _tokenDisplayName(next);
        return 'Cannot extract: $currentName$nextName has no separator '
            'between variables';
      }
    }

    return null;
  }

  /// Extracts tag values from [path] using the given [tokens].
  ///
  /// Returns an [ExtractionResult] containing the extracted tag-value pairs,
  /// or a non-match result if the path does not match the mask structure.
  ///
  /// The [path] should already have the file extension stripped and the
  /// appropriate scope applied (filename only, relative, or absolute).
  ExtractionResult extract(List<MaskToken> tokens, String path) {
    if (tokens.isEmpty) {
      return ExtractionResult(filePath: path, matched: false);
    }

    // Validate: no adjacent variables.
    final validationError = validateForExtraction(tokens);
    if (validationError != null) {
      return ExtractionResult(filePath: path, matched: false);
    }

    // Handle leading literal: if the mask starts with a literal, the path
    // must start with that literal. Strip it before proceeding.
    var workingPath = path;
    var tokenStart = 0;

    if (tokens.first is LiteralToken) {
      final leadingLiteral = (tokens.first as LiteralToken).text;
      if (!workingPath.startsWith(leadingLiteral)) {
        return ExtractionResult(filePath: path, matched: false);
      }
      workingPath = workingPath.substring(leadingLiteral.length);
      tokenStart = 1;
    }

    // Handle trailing literal: if the mask ends with a literal, the path
    // must end with that literal. Strip it before proceeding.
    var tokenEnd = tokens.length;

    if (tokenEnd > tokenStart && tokens.last is LiteralToken) {
      final trailingLiteral = (tokens.last as LiteralToken).text;
      if (!workingPath.endsWith(trailingLiteral)) {
        return ExtractionResult(filePath: path, matched: false);
      }
      workingPath =
          workingPath.substring(0, workingPath.length - trailingLiteral.length);
      tokenEnd = tokenEnd - 1;
    }

    // Collect the variable/ignore slots and their interleaving literal
    // delimiters from the remaining tokens.
    final slots = <MaskToken>[];
    final delimiters = <String>[];

    for (var i = tokenStart; i < tokenEnd; i++) {
      final token = tokens[i];
      if (_isVariableOrIgnore(token)) {
        slots.add(token);
      } else if (token is LiteralToken) {
        delimiters.add(token.text);
      }
    }

    // If there are no variable/ignore slots, the mask is all literals.
    // The path should be empty after stripping leading/trailing literals.
    if (slots.isEmpty) {
      if (workingPath.isEmpty) {
        return ExtractionResult(filePath: path, matched: true);
      }
      return ExtractionResult(filePath: path, matched: false);
    }

    // Split the working path on delimiters left-to-right (greedy for the
    // leftmost variable — split at first occurrence of each delimiter).
    final segments = <String>[];
    var remaining = workingPath;

    for (final delimiter in delimiters) {
      final index = remaining.indexOf(delimiter);
      if (index == -1) {
        // Delimiter not found — path doesn't match.
        return ExtractionResult(filePath: path, matched: false);
      }
      segments.add(remaining.substring(0, index));
      remaining = remaining.substring(index + delimiter.length);
    }

    // The last segment is whatever remains after the last delimiter.
    segments.add(remaining);

    // Verify segment count matches slot count.
    if (segments.length != slots.length) {
      return ExtractionResult(filePath: path, matched: false);
    }

    // Map segments to tag variables, skipping ignore tokens.
    final extractedTags = <String, String>{};

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final segment = segments[i];

      if (slot is VariableToken) {
        extractedTags[slot.variable.maskName] = segment;
      }
      // IgnoreToken: discard the segment.
    }

    return ExtractionResult(
      filePath: path,
      matched: true,
      extractedTags: extractedTags,
    );
  }

  /// Returns true if the token is a variable or ignore token.
  bool _isVariableOrIgnore(MaskToken token) {
    return token is VariableToken || token is IgnoreToken;
  }

  /// Returns a display name for a token (for error messages).
  String _tokenDisplayName(MaskToken token) {
    if (token is VariableToken) {
      return '%${token.variable.maskName}';
    }
    if (token is IgnoreToken) {
      return '%ignore';
    }
    if (token is LiteralToken) {
      return token.text;
    }
    return '';
  }
}
