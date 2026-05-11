/// Preview of extraction results for a single file.
class ExtractionPreview {
  const ExtractionPreview({
    required this.filePath,
    required this.filename,
    required this.matched,
    this.extractedTags = const {},
    this.transformedTags = const {},
  });

  /// Original file path.
  final String filePath;

  /// Display filename.
  final String filename;

  /// Whether the file's path matched the mask.
  final bool matched;

  /// Raw extracted values (before transformation).
  final Map<String, String> extractedTags;

  /// Transformed values (after case/underscore/trim processing).
  final Map<String, String> transformedTags;
}
