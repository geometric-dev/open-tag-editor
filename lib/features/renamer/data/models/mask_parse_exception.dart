/// Exception thrown when a mask pattern contains invalid syntax.
class MaskParseException implements Exception {
  /// Creates a [MaskParseException] with the given [message] and [position].
  const MaskParseException({required this.message, required this.position});

  /// Human-readable description of the parse error.
  final String message;

  /// Character position in the pattern where the error was detected.
  final int position;

  @override
  String toString() => 'MaskParseException at position $position: $message';
}
