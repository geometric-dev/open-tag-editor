import '../../renamer/data/case_transformer.dart';
import '../../renamer/data/models/case_option.dart';

/// Applies the full transformation pipeline to extracted tag values.
///
/// Transformation order:
/// 1. Replace underscores with spaces (if enabled)
/// 2. Apply case transformation
/// 3. Trim whitespace (if enabled)
class ValueTransformer {
  /// Creates a [ValueTransformer] instance.
  const ValueTransformer({CaseTransformer? caseTransformer})
    : _caseTransformer = caseTransformer ?? const CaseTransformer();

  final CaseTransformer _caseTransformer;

  /// Transforms a single extracted value through the full pipeline.
  String transform(
    String value, {
    required CaseOption caseOption,
    required bool replaceUnderscores,
    required bool trimWhitespace,
  }) {
    // Steps 1 & 2: CaseTransformer handles underscore replacement and case.
    var result = _caseTransformer.transform(
      value,
      option: caseOption,
      replaceUnderscores: replaceUnderscores,
    );

    // Step 3: Trim whitespace.
    if (trimWhitespace) {
      result = result.trim();
    }

    return result;
  }

  /// Transforms all values in a tag map through the full pipeline.
  Map<String, String> transformAll(
    Map<String, String> tags, {
    required CaseOption caseOption,
    required bool replaceUnderscores,
    required bool trimWhitespace,
  }) {
    return tags.map(
      (key, value) => MapEntry(
        key,
        transform(
          value,
          caseOption: caseOption,
          replaceUnderscores: replaceUnderscores,
          trimWhitespace: trimWhitespace,
        ),
      ),
    );
  }
}
