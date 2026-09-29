import 'package:flutter/material.dart';

import '../../../renamer/data/models/mask_token.dart';
import '../../data/models/extraction_preview.dart';

/// Displays a tabular preview of extraction results.
///
/// Shows one column per tag variable in the mask, with rows for each file.
/// Non-matching files are visually highlighted and matched files have
/// deselection checkboxes.
class ExtractorPreviewPanel extends StatelessWidget {
  const ExtractorPreviewPanel({
    super.key,
    required this.previews,
    required this.tokens,
    required this.deselectedFiles,
    required this.onToggleSelection,
  });

  /// The extraction previews to display.
  final List<ExtractionPreview> previews;

  /// The parsed mask tokens (used to determine column headers).
  final List<MaskToken> tokens;

  /// Set of file paths that have been deselected by the user.
  final Set<String> deselectedFiles;

  /// Callback when a file's selection is toggled.
  final ValueChanged<String> onToggleSelection;

  /// Extracts the variable names from the token list for column headers.
  List<String> get _variableNames {
    final names = <String>[];
    for (final token in tokens) {
      if (token is VariableToken) {
        names.add(token.variable.displayName);
      }
    }
    return names;
  }

  /// Extracts the variable mask names for looking up values.
  List<String> get _variableMaskNames {
    final names = <String>[];
    for (final token in tokens) {
      if (token is VariableToken) {
        names.add(token.variable.maskName);
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final variableNames = _variableNames;
    final variableMaskNames = _variableMaskNames;

    final matchedCount = previews.where((p) => p.matched).length;
    final unmatchedCount = previews.where((p) => !p.matched).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$matchedCount matched, $unmatchedCount not matched',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),

        // Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(4),
            ),
            child: previews.isEmpty
                ? const Center(
                    child: Text(
                      'Enter a mask pattern to preview extraction',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : Column(
                    children: [
                      // Header row
                      _TableHeader(variableNames: variableNames),
                      const Divider(height: 1),
                      // Data rows
                      Expanded(
                        child: ListView.builder(
                          itemCount: previews.length,
                          itemBuilder: (context, index) {
                            final preview = previews[index];
                            return _PreviewRow(
                              preview: preview,
                              variableMaskNames: variableMaskNames,
                              isDeselected: deselectedFiles.contains(
                                preview.filePath,
                              ),
                              onToggle: () =>
                                  onToggleSelection(preview.filePath),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.variableNames});

  final List<String> variableNames;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Checkbox column
          const SizedBox(width: 32),
          // Filename column
          const Expanded(
            flex: 2,
            child: Text(
              'File',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Variable columns
          for (final name in variableNames)
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.preview,
    required this.variableMaskNames,
    required this.isDeselected,
    required this.onToggle,
  });

  final ExtractionPreview preview;
  final List<String> variableMaskNames;
  final bool isDeselected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMatched = preview.matched;

    final backgroundColor = isMatched
        ? null
        : colorScheme.errorContainer.withValues(alpha: 0.3);

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Checkbox (only for matched files)
          SizedBox(
            width: 32,
            child: isMatched
                ? Checkbox(
                    value: !isDeselected,
                    onChanged: (_) => onToggle(),
                    visualDensity: VisualDensity.compact,
                  )
                : Icon(Icons.close, size: 14, color: colorScheme.error),
          ),
          // Filename
          Expanded(
            flex: 2,
            child: Text(
              preview.filename,
              style: TextStyle(
                fontSize: 11,
                color: isMatched
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Variable values
          for (final maskName in variableMaskNames)
            Expanded(
              child: Text(
                isMatched ? (preview.transformedTags[maskName] ?? '') : '',
                style: TextStyle(
                  fontSize: 11,
                  color: isMatched
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
