import 'models/mask_parse_exception.dart';
import 'models/mask_token.dart';
import 'models/tag_variable.dart';

/// Parses mask pattern strings into structured token lists.
class MaskParser {
  /// Parses [pattern] into a list of tokens.
  ///
  /// Throws [MaskParseException] if the pattern contains an unrecognized
  /// variable name after a `%` character.
  List<MaskToken> parse(String pattern) {
    final tokens = <MaskToken>[];
    final literal = StringBuffer();

    var i = 0;
    while (i < pattern.length) {
      if (pattern[i] == '%') {
        final startPos = i;
        i++;

        // If % is at the end of the string, treat as literal
        if (i >= pattern.length) {
          literal.write('%');
          break;
        }

        // Read the following word (letters only)
        final nameBuffer = StringBuffer();
        while (i < pattern.length && _isLetter(pattern[i])) {
          nameBuffer.write(pattern[i]);
          i++;
        }

        final name = nameBuffer.toString();

        // If no letters followed %, treat % as literal
        if (name.isEmpty) {
          literal.write('%');
          continue;
        }

        // Flush any accumulated literal text
        if (literal.isNotEmpty) {
          tokens.add(LiteralToken(literal.toString()));
          literal.clear();
        }

        final lowerName = name.toLowerCase();

        if (lowerName == 'ignore') {
          tokens.add(const IgnoreToken());
        } else {
          final variable = TagVariable.fromMaskName(lowerName);
          if (variable != null) {
            tokens.add(VariableToken(variable));
          } else {
            throw MaskParseException(
              message: 'Unknown variable: $name',
              position: startPos,
            );
          }
        }
      } else {
        literal.write(pattern[i]);
        i++;
      }
    }

    // Flush remaining literal text
    if (literal.isNotEmpty) {
      tokens.add(LiteralToken(literal.toString()));
    }

    return tokens;
  }

  /// Converts a token list back to a mask string.
  String format(List<MaskToken> tokens) {
    final buffer = StringBuffer();
    for (final token in tokens) {
      switch (token) {
        case LiteralToken(:final text):
          buffer.write(text);
        case VariableToken(:final variable):
          buffer.write('%${variable.maskName}');
        case IgnoreToken():
          buffer.write('%ignore');
      }
    }
    return buffer.toString();
  }

  bool _isLetter(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }
}
