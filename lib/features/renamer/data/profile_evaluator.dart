import '../../../shared/models/audio_file.dart';
import 'models/rename_profile.dart';

/// Evaluates [RenameProfile] conditions against audio files.
///
/// Kept free of Flutter and provider dependencies so it is trivially testable.
/// The rename dialog uses it to pick the first matching profile for the
/// current selection.
class ProfileEvaluator {
  const ProfileEvaluator();

  /// Returns the first profile in [profiles] whose conditions all match
  /// [file], or null if none match.
  ///
  /// Profiles are evaluated in order, so the caller controls precedence by
  /// list position (most specific first).
  RenameProfile? firstMatch(
    List<RenameProfile> profiles,
    AudioFile file, {
    int folderDepth = 0,
  }) {
    for (final profile in profiles) {
      if (matches(profile, file, folderDepth: folderDepth)) return profile;
    }
    return null;
  }

  /// Whether [profile] matches [file].
  ///
  /// Each condition group is ANDed; the profile matches when **any** group
  /// matches (OR). A profile with no groups is a catch-all and always matches.
  bool matches(RenameProfile profile, AudioFile file, {int folderDepth = 0}) {
    if (profile.conditionGroups.isEmpty) return true;
    for (final group in profile.conditionGroups) {
      if (_groupMatches(group, file, folderDepth)) return true;
    }
    return false;
  }

  bool _groupMatches(
    List<ProfileCondition> group,
    AudioFile file,
    int folderDepth,
  ) {
    for (final condition in group) {
      if (!_conditionMatches(condition, file, folderDepth)) return false;
    }
    return true;
  }

  bool _conditionMatches(
    ProfileCondition condition,
    AudioFile file,
    int folderDepth,
  ) {
    final actual = resolveField(
      condition.field,
      file,
      folderDepth: folderDepth,
    );
    final expected = condition.value;

    switch (condition.operator) {
      case ProfileOperator.equals:
        return _ci(actual) == _ci(expected);
      case ProfileOperator.notEquals:
        return _ci(actual) != _ci(expected);
      case ProfileOperator.contains:
        return _ci(actual).contains(_ci(expected));
      case ProfileOperator.notContains:
        return !_ci(actual).contains(_ci(expected));
      case ProfileOperator.isSet:
        return actual.trim().isNotEmpty;
      case ProfileOperator.isNotSet:
        return actual.trim().isEmpty;
      case ProfileOperator.greaterThan:
        final a = num.tryParse(actual.trim());
        final b = num.tryParse(expected.trim());
        return a != null && b != null && a > b;
    }
  }

  /// Resolves [field] to its string value for [file].
  ///
  /// Supports arbitrary tag fields (case-insensitive), plus computed
  /// pseudo-fields: `discCount`, `trackCount`, and `folderDepth`.
  String resolveField(String field, AudioFile file, {int folderDepth = 0}) {
    final key = field.trim().toLowerCase();

    switch (key) {
      case 'disccount':
        return _totalOf(file.tags['discNumber'] ?? '');
      case 'trackcount':
        return _totalOf(file.tags['trackNumber'] ?? '');
      case 'folderdepth':
        return folderDepth.toString();
    }

    // Fall back to a direct tag lookup, then a case-insensitive scan.
    final direct = file.tags[field];
    if (direct != null) return direct;
    for (final entry in file.tags.entries) {
      if (entry.key.toLowerCase() == key) return entry.value;
    }
    return '';
  }

  /// Extracts the "/total" portion of a "current/total" tag value, or empty
  /// if there is no slash.
  String _totalOf(String value) {
    if (!value.contains('/')) return '';
    return value.split('/').last.trim();
  }

  String _ci(String value) => value.trim().toLowerCase();
}
