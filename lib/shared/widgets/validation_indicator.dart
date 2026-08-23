import 'package:flutter/material.dart';

import '../services/tag_field_validator.dart';

/// Displays a warning or error icon with a tooltip explaining the issue.
///
/// Shows the highest-severity icon when multiple issues exist.
/// Tooltip lists all issue messages joined with newlines.
/// Renders nothing (zero visual footprint) when [issues] is empty.
class ValidationIndicator extends StatelessWidget {
  /// Creates a [ValidationIndicator] for the given [issues].
  const ValidationIndicator({
    super.key,
    required this.issues,
    this.iconSize = 16,
  });

  /// The validation issues to display. Empty list renders nothing.
  final List<TagFieldIssue> issues;

  /// The size of the icon. Defaults to 16.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();

    final hasError =
        issues.any((i) => i.severity == TagFieldSeverity.error);
    final icon = hasError ? Icons.error_outline : Icons.warning_amber;
    final color = hasError
        ? Theme.of(context).colorScheme.error
        : Colors.orange;
    final tooltipText = issues.map((i) => i.message).join('\n');

    return Tooltip(
      message: tooltipText,
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
