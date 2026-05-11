import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/audio_file.dart';
import '../../../tag_editor/data/providers/editor_state_provider.dart';
import '../../data/models/lookup_state.dart';
import '../../data/providers/lookup_state_provider.dart';
import '../../data/providers/service_providers.dart';
import 'lookup_apply_panel.dart';
import 'lookup_match_panel.dart';
import 'lookup_results_panel.dart';
import 'lookup_search_panel.dart';

/// Shows the online metadata lookup dialog.
///
/// Pre-fills search fields from the currently selected files.
Future<void> showLookupDialog(BuildContext context, WidgetRef ref) {
  final selectedFiles = ref.read(selectedFilesProvider);

  // Configure the state notifier with services
  final notifier = ref.read(lookupStateProvider.notifier);
  notifier.configure(
    musicBrainzService: ref.read(musicBrainzServiceProvider),
    discogsService: ref.read(discogsServiceProvider),
    acoustIdService: ref.read(acoustIdServiceProvider),
    fingerprintGenerator: ref.read(fingerprintGeneratorProvider),
    coverArtService: ref.read(coverArtServiceProvider),
    metadataApplicator: ref.read(metadataApplicatorProvider),
    cache: ref.read(lookupCacheProvider),
  );

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lookupStateProvider);

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
