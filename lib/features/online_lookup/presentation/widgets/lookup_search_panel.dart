import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/audio_file.dart';
import '../../data/lookup_helpers.dart';
import '../../data/models/lookup_state.dart';
import '../../data/models/search_result.dart';
import '../../data/providers/lookup_settings_provider.dart';
import '../../data/providers/lookup_state_provider.dart';

/// Search form panel for the lookup dialog.
class LookupSearchPanel extends ConsumerStatefulWidget {
  const LookupSearchPanel({
    super.key,
    required this.selectedFiles,
    required this.status,
    this.error,
    this.fingerprintProgress,
  });

  final List<AudioFile> selectedFiles;
  final LookupStatus status;
  final String? error;
  final FingerprintProgress? fingerprintProgress;

  @override
  ConsumerState<LookupSearchPanel> createState() => _LookupSearchPanelState();
}

class _LookupSearchPanelState extends ConsumerState<LookupSearchPanel> {
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late final TextEditingController _yearController;
  Set<SearchSource> _selectedSources = {SearchSource.musicBrainz};

  @override
  void initState() {
    super.initState();
    final preFill = LookupHelpers.extractPreFillData(widget.selectedFiles);
    _artistController = TextEditingController(text: preFill.artist);
    _albumController = TextEditingController(text: preFill.album);
    _yearController = TextEditingController();

    final settings = ref.read(lookupSettingsProvider);
    _selectedSources = {settings.defaultSource};
    if (settings.isDiscogsConfigured &&
        settings.defaultSource == SearchSource.musicBrainz) {
      // Keep just MusicBrainz as default
    }
  }

  @override
  void dispose() {
    _artistController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _search() {
    ref.read(lookupStateProvider.notifier).search(
          artist: _artistController.text,
          album: _albumController.text,
          year: _yearController.text.isNotEmpty ? _yearController.text : null,
          sources: _selectedSources,
        );
  }

  void _identify() {
    ref.read(lookupStateProvider.notifier).identifyFiles(widget.selectedFiles);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(lookupSettingsProvider);
    final isSearching = widget.status == LookupStatus.searching;
    final isFingerprinting = widget.status == LookupStatus.fingerprinting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search fields
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _artistController,
                decoration: const InputDecoration(
                  labelText: 'Artist',
                  isDense: true,
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _albumController,
                decoration: const InputDecoration(
                  labelText: 'Album',
                  isDense: true,
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  isDense: true,
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Source selector and actions
        Row(
          children: [
            // Source chips
            FilterChip(
              label: const Text('MusicBrainz'),
              selected: _selectedSources.contains(SearchSource.musicBrainz),
              onSelected: (v) => setState(() {
                if (v) {
                  _selectedSources.add(SearchSource.musicBrainz);
                } else {
                  _selectedSources.remove(SearchSource.musicBrainz);
                }
              }),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Discogs'),
              selected: _selectedSources.contains(SearchSource.discogs),
              onSelected: settings.isDiscogsConfigured
                  ? (v) => setState(() {
                        if (v) {
                          _selectedSources.add(SearchSource.discogs);
                        } else {
                          _selectedSources.remove(SearchSource.discogs);
                        }
                      })
                  : null,
              avatar: settings.isDiscogsConfigured
                  ? null
                  : Icon(
                      Icons.link_off,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              tooltip: settings.isDiscogsConfigured
                  ? null
                  : 'Configure Discogs token in Settings → Online Lookup',
            ),
            const Spacer(),
            // Identify button
            OutlinedButton.icon(
              onPressed: isFingerprinting ? null : _identify,
              icon: const Icon(Icons.fingerprint, size: 16),
              label: const Text('Identify'),
            ),
            const SizedBox(width: 8),
            // Search button
            FilledButton.icon(
              onPressed: isSearching ? null : _search,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Status area
        if (isSearching) const Center(child: CircularProgressIndicator()),
        if (isFingerprinting && widget.fingerprintProgress != null)
          Column(
            children: [
              LinearProgressIndicator(
                value: widget.fingerprintProgress!.completed /
                    widget.fingerprintProgress!.total,
              ),
              const SizedBox(height: 8),
              Text(
                'Fingerprinting ${widget.fingerprintProgress!.completed}'
                '/${widget.fingerprintProgress!.total}...',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.error!)),
                    TextButton(
                      onPressed: _search,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Empty state hint
        if (!isSearching && !isFingerprinting && widget.error == null)
          Expanded(
            child: Center(
              child: Text(
                'Search by artist/album or identify files by fingerprint',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
