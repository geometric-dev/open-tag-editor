import 'package:flutter/material.dart';

import '../../../../shared/models/audio_file.dart';
import '../../data/models/cover_art_result.dart';
import '../../data/models/search_result.dart';

/// Panel showing track listing and cover art for matching.
class LookupMatchPanel extends StatelessWidget {
  const LookupMatchPanel({
    super.key,
    required this.trackListing,
    required this.coverArt,
    required this.coverArtLoading,
    required this.selectedFiles,
    required this.onMatch,
    required this.onBack,
    this.onPartialMatch,
  });

  final List<TrackInfo> trackListing;
  final CoverArtResult? coverArt;
  final bool coverArtLoading;
  final List<AudioFile> selectedFiles;
  final VoidCallback onMatch;
  final VoidCallback onBack;
  final VoidCallback? onPartialMatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with back button
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: onBack,
              tooltip: 'Back to results',
            ),
            Text(
              '${trackListing.length} tracks',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            if (trackListing.length < selectedFiles.length) ...[
              OutlinedButton.icon(
                onPressed: onPartialMatch,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Apply as Partial Match'),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              onPressed: onMatch,
              icon: const Icon(Icons.compare_arrows, size: 16),
              label: Text('Match to ${selectedFiles.length} file(s)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Content: track list + cover art
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Track listing
              Expanded(
                child: ListView.builder(
                  itemCount: trackListing.length,
                  itemBuilder: (context, index) {
                    final track = trackListing[index];
                    final durationStr = track.durationMs != null
                        ? _formatDuration(track.durationMs!)
                        : '';
                    return ListTile(
                      dense: true,
                      leading: Text(
                        '${track.position}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      title: Text(
                        track.title,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: track.artist != null
                          ? Text(
                              track.artist!,
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
                      trailing: Text(
                        durationStr,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
              // Cover art preview
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    if (coverArtLoading)
                      const SizedBox(
                        width: 200,
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (coverArt != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          coverArt!.imageBytes,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 48),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      coverArt != null ? 'Cover art available' : 'No cover art',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(int ms) {
    final seconds = ms ~/ 1000;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
