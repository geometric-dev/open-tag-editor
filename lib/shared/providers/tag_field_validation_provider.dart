import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/models/tag_write_options.dart';
import '../../features/settings/data/providers/settings_providers.dart';
import '../services/tag_field_validator.dart';
import '../services/taglib/taglib_types.dart';

/// Provides the current [TagWriteOptions] derived from user settings.
///
/// Reactively rebuilds when the user changes write settings, so any
/// widget watching this provider will re-validate automatically.
final tagWriteOptionsProvider = Provider<TagWriteOptions>((ref) {
  final settings = ref.watch(tagWritingSettingsProvider);
  return TagWriteOptions(
    id3v2Version: settings.id3v2Version,
    writeId3v1: settings.writeId3v1,
    encoding: settings.encoding,
  );
});

/// Validates a tag field value against the current write settings.
///
/// Usage:
/// ```dart
/// final issues = ref.read(tagFieldValidationProvider)(
///   field: 'title',
///   value: controller.text,
///   tagFormat: audioFile.tagFormat,
/// );
/// ```
final tagFieldValidationProvider = Provider<TagFieldValidationFn>((ref) {
  final options = ref.watch(tagWriteOptionsProvider);

  return ({
    required String field,
    required String value,
    TagFormat? tagFormat,
  }) {
    return TagFieldValidator.validate(
      field: field,
      value: value,
      options: options,
      tagFormat: tagFormat,
    );
  };
});

/// Function signature for the tag field validation provider.
typedef TagFieldValidationFn = List<TagFieldIssue> Function({
  required String field,
  required String value,
  TagFormat? tagFormat,
});
