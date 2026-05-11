import 'tag_variable.dart';

/// A single token in a parsed mask pattern.
sealed class MaskToken {
  const MaskToken();
}

/// A literal text segment (e.g., " - ", "/").
class LiteralToken extends MaskToken {
  const LiteralToken(this.text);

  /// The literal text content.
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LiteralToken && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'LiteralToken("$text")';
}

/// A tag variable placeholder (e.g., %artist, %track).
class VariableToken extends MaskToken {
  const VariableToken(this.variable);

  /// The tag variable this token represents.
  final TagVariable variable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariableToken && other.variable == variable;

  @override
  int get hashCode => variable.hashCode;

  @override
  String toString() => 'VariableToken(${variable.maskName})';
}

/// Represents the %ignore placeholder.
class IgnoreToken extends MaskToken {
  const IgnoreToken();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IgnoreToken;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'IgnoreToken()';
}
