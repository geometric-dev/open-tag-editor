/// A saved mask preset for quick recall.
class MaskPreset {
  const MaskPreset({
    required this.name,
    required this.pattern,
    this.isBuiltIn = false,
  });

  /// User-visible name of the preset.
  final String name;

  /// The mask pattern string.
  final String pattern;

  /// Whether this is a built-in default (cannot be deleted).
  final bool isBuiltIn;

  /// Creates a MaskPreset from a JSON map.
  factory MaskPreset.fromJson(Map<String, dynamic> json) {
    return MaskPreset(
      name: json['name'] as String,
      pattern: json['pattern'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  /// Converts this preset to a JSON map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'pattern': pattern,
        'isBuiltIn': isBuiltIn,
      };
}
