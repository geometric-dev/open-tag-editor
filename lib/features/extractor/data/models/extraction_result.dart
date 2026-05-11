/// Result of extracting tag values from a single file path.
class ExtractionResult {
  const ExtractionResult({
    required this.filePath,
    required this.matched,
    this.extractedTags = const {},
  });

  /// The original file path.
  final String filePath;

  /// Whether the path matched the mask structure.
  final bool matched;

  /// Extracted tag field → value pairs (empty if not matched).
  /// Keys are tag field names (e.g., 'artist', 'title', 'album').
  final Map<String, String> extractedTags;
}
