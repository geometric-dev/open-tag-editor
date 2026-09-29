/// Direction for sibling folder navigation.
enum SiblingDirection { next, previous }

/// Resolves sibling folder navigation without filesystem access.
///
/// Provides pure-function logic for filtering hidden directories and
/// determining the next or previous sibling in case-insensitive
/// alphabetical order.
class SiblingResolver {
  /// Filters [directoryNames] to exclude hidden folders (names starting
  /// with a dot) and sorts the result case-insensitively.
  List<String> filterAndSort(List<String> directoryNames) {
    final visible = directoryNames
        .where((name) => !name.startsWith('.'))
        .toList();
    visible.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return visible;
  }

  /// Given a sorted list of [siblingNames] (case-insensitive alphabetical)
  /// and the [currentName], returns the next or previous sibling name.
  ///
  /// Returns null if [currentName] is not found in the list, or if
  /// navigating in [direction] would go out of bounds.
  String? resolve({
    required List<String> siblingNames,
    required String currentName,
    required SiblingDirection direction,
  }) {
    final index = siblingNames.indexWhere(
      (name) => name.toLowerCase() == currentName.toLowerCase(),
    );
    if (index == -1) return null;

    switch (direction) {
      case SiblingDirection.next:
        if (index >= siblingNames.length - 1) return null;
        return siblingNames[index + 1];
      case SiblingDirection.previous:
        if (index <= 0) return null;
        return siblingNames[index - 1];
    }
  }
}
