import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/audio_file.dart';
import '../../../tag_editor/data/providers/editor_state_provider.dart';
import '../../data/models/lookup_state.dart';
import '../../data/providers/lookup_state_provider.dart';
import 'lookup_apply_panel.dart';
import 'lookup_match_panel.dart';
import 'lookup_results_panel.dart';
import 'lookup_search_panel.dart';

/// Shows the online metadata lookup dialog.
///
/// Pre-fills search fields from the currently selected files. Services are
/// constructor-injected via [lookupStateProvider]; no manual configuration
/// is needed here.
Future<void> showLookupDialog(BuildContext context, WidgetRef ref) {
  final selectedFiles = ref.read(selectedFilesProvider);

  return showDialog(
    context: context,
    builder: (_) => LookupDialog(selectedFiles: selectedFiles),
  );
}

/// The online metadata lookup dialog.
class LookupDialog extends ConsumerStatefulWidget {
  const LookupDialog({super.key, required this.selectedFiles});

  final List<AudioFile> selectedFiles;

  @override
  ConsumerState<LookupDialog> createState() => _LookupDialogState();
}

class _LookupDialogState extends ConsumerState<LookupDialog> {
  @override
  void dispose() {
    ref.read(lookupStateProvider.notifier).cancel();
    super.dispose();
  }

  int _currentStep(LookupState state) {
    if (state.matches.isNotEmpty) return 4;
    if (state.trackListing.isNotEmpty) return 3;
    if (state.searchResults.isNotEmpty) return 2;
    return 1;
  }

  Widget _buildStepIndicator(BuildContext context, int currentStep) {
    const steps = ['Search', 'Results', 'Tracks', 'Apply'];
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Text(
              ' › ',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            steps[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  i + 1 == currentStep ? FontWeight.bold : FontWeight.normal,
              color: i + 1 == currentStep
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lookupStateProvider);
    final step = _currentStep(state);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 650,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Online Metadata Lookup',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 16),
                  _buildStepIndicator(context, step),
                  const Spacer(),
                  if (state.queueLength > 0)
                    Chip(
                      label: Text('${state.queueLength} queued'),
                      avatar: const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              // Content area
              Expanded(
                child: _buildContent(state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LookupState state) {
    // Show apply panel if we have matches
    if (state.matches.isNotEmpty) {
      return LookupApplyPanel(
        matches: state.matches,
        coverArt: state.coverArt,
        status: state.status,
        isPartialMatch: state.isPartialMatch,
        allSelectedFiles: state.allSelectedFiles,
        optedOutPaths: state.optedOutPaths,
        trackListing: state.trackListing,
        onBack: () {
          ref.read(lookupStateProvider.notifier).updateMatching([]);
        },
      );
    }

    // Show match panel if we have a track listing
    if (state.trackListing.isNotEmpty) {
      return LookupMatchPanel(
        trackListing: state.trackListing,
        coverArt: state.coverArt,
        coverArtLoading: state.coverArtLoading,
        selectedFiles: widget.selectedFiles,
        onMatch: () {
          ref.read(lookupStateProvider.notifier).matchFiles(
                widget.selectedFiles,
              );
        },
        onBack: () {
          ref.read(lookupStateProvider.notifier).deselectResult();
        },
        onPartialMatch: () {
          ref.read(lookupStateProvider.notifier).matchFilesPartial(
                widget.selectedFiles,
              );
        },
      );
    }

    // Show results if we have them
    if (state.searchResults.isNotEmpty) {
      return LookupResultsPanel(
        results: state.searchResults,
        status: state.status,
        onSelectResult: (result) {
          ref.read(lookupStateProvider.notifier).selectResult(result);
        },
      );
    }

    // Default: search panel
    return LookupSearchPanel(
      selectedFiles: widget.selectedFiles,
      status: state.status,
      error: state.error,
      fingerprintProgress: state.fingerprintProgress,
    );
  }
}
