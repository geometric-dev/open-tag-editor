/// A single condition that must hold for a [RenameProfile] to apply.
///
/// A condition compares one field of an audio file's tag set (or a computed
/// pseudo-field such as disc count) against an expected value. Conditions
/// within one group of a profile are ANDed; a profile matches when any of its
/// groups matches (OR).
class ProfileCondition {
  const ProfileCondition({
    required this.field,
    required this.operator,
    this.value = '',
  });

  /// The tag field to test, e.g. "albumArtist", "genre", "album".
  ///
  /// Case-insensitive. A few computed pseudo-fields are also accepted:
  /// "discCount" / "trackCount" (the "/total" part of a track/disc number)
  /// and "folderDepth" (how many directories deep the file sits below the
  /// loaded root).
  final String field;

  /// How to compare the field's value to [value].
  final ProfileOperator operator;

  /// The value to compare against. Ignored for [ProfileOperator.isSet] /
  /// [ProfileOperator.isNotSet].
  final String value;

  /// Creates a copy with updated fields.
  ProfileCondition copyWith({
    String? field,
    ProfileOperator? operator,
    String? value,
  }) {
    return ProfileCondition(
      field: field ?? this.field,
      operator: operator ?? this.operator,
      value: value ?? this.value,
    );
  }

  /// Creates a [ProfileCondition] from a JSON map.
  factory ProfileCondition.fromJson(Map<String, dynamic> json) {
    return ProfileCondition(
      field: json['field'] as String? ?? '',
      operator: ProfileOperator.fromName(json['operator'] as String? ?? ''),
      value: json['value'] as String? ?? '',
    );
  }

  /// Converts this condition to a JSON map.
  Map<String, dynamic> toJson() => {
    'field': field,
    'operator': operator.name,
    'value': value,
  };
}

/// The comparison operators a [ProfileCondition] can use.
enum ProfileOperator {
  /// Field equals the value (case-insensitive).
  equals('equals'),

  /// Field does not equal the value (case-insensitive).
  notEquals('not equals'),

  /// Field contains the value as a substring (case-insensitive).
  contains('contains'),

  /// Field does not contain the value (case-insensitive).
  notContains('does not contain'),

  /// Field has a non-empty value.
  isSet('is set'),

  /// Field is empty or absent.
  isNotSet('is not set'),

  /// The numeric value is greater than the value.
  greaterThan('is greater than');

  const ProfileOperator(this.label);

  /// Human-readable label for the settings UI.
  final String label;

  /// Looks up an operator by its persisted [name].
  static ProfileOperator fromName(String name) {
    for (final op in values) {
      if (op.name == name) return op;
    }
    return ProfileOperator.equals;
  }
}

/// A named, conditional rename pattern.
///
/// A profile pairs a mask [pattern] with one or more **condition groups**.
/// Each group is a list of conditions that are ANDed together; the groups
/// themselves are ORed. So a single profile can match several alternative
/// shapes while producing one pattern — e.g. "AlbumArtist is Various Artists"
/// **or** "AlbumArtist is OST" **or** "AlbumArtist is Soundtrack", all sharing
/// the same mask. That is the point: you maintain the pattern in one place
/// instead of duplicating a near-identical profile per value.
///
/// The rename dialog picks the first profile (by list order) that matches, so
/// put more specific profiles above more general ones. A profile with no
/// condition groups is a catch-all and always matches.
///
/// Profiles are the rule-based, no-scripting way to get "Standard" vs
/// "Various Artists" vs "Compilation" vs "multi-disc" behaviour without
/// manually flipping presets: each release shape gets its own row, matched
/// automatically from tags.
class RenameProfile {
  const RenameProfile({
    required this.name,
    required this.pattern,
    this.conditionGroups = const [],
    this.isBuiltIn = false,
  });

  /// Convenience constructor for a profile with a single AND group.
  ///
  /// Equivalent to `conditionGroups: [conditions]`. Provided so callers that
  /// only need one group (and the common "no conditions = catch-all" case)
  /// stay readable.
  factory RenameProfile.singleGroup({
    required String name,
    required String pattern,
    List<ProfileCondition> conditions = const [],
    bool isBuiltIn = false,
  }) {
    return RenameProfile(
      name: name,
      pattern: pattern,
      conditionGroups: conditions.isEmpty ? const [] : [conditions],
      isBuiltIn: isBuiltIn,
    );
  }

  /// User-visible name, e.g. "Various Artists / OST / Soundtrack".
  final String name;

  /// The mask pattern to apply when this profile matches.
  final String pattern;

  /// Alternative condition sets, ORed together.
  ///
  /// Each inner list is ANDed (all must hold). The profile matches when
  /// **any** inner list matches. An empty outer list means catch-all.
  final List<List<ProfileCondition>> conditionGroups;

  /// Whether this is a built-in default (cannot be deleted).
  final bool isBuiltIn;

  /// Whether this profile has no conditions and therefore always matches.
  bool get isCatchAll => conditionGroups.isEmpty;

  /// Creates a copy with updated fields.
  RenameProfile copyWith({
    String? name,
    String? pattern,
    List<List<ProfileCondition>>? conditionGroups,
    bool? isBuiltIn,
  }) {
    return RenameProfile(
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      conditionGroups: conditionGroups ?? this.conditionGroups,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  /// Creates a [RenameProfile] from a JSON map.
  ///
  /// Reads the current `conditionGroups` shape, and falls back to the legacy
  /// flat `conditions` list (treated as a single AND group) so profiles saved
  /// by an earlier build keep working.
  factory RenameProfile.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['conditionGroups'] as List<dynamic>?;
    final List<List<ProfileCondition>> groups;
    if (rawGroups != null) {
      groups = rawGroups
          .map(
            (g) => (g as List<dynamic>)
                .map(
                  (e) => ProfileCondition.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
          )
          .toList();
    } else {
      final legacy = json['conditions'] as List<dynamic>? ?? const [];
      groups = legacy.isEmpty
          ? const []
          : [
              legacy
                  .map(
                    (e) => ProfileCondition.fromJson(e as Map<String, dynamic>),
                  )
                  .toList(),
            ];
    }
    return RenameProfile(
      name: json['name'] as String? ?? '',
      pattern: json['pattern'] as String? ?? '',
      conditionGroups: groups,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  /// Converts this profile to a JSON map.
  Map<String, dynamic> toJson() => {
    'name': name,
    'pattern': pattern,
    'conditionGroups': conditionGroups
        .map((g) => g.map((c) => c.toJson()).toList())
        .toList(),
    'isBuiltIn': isBuiltIn,
  };
}
