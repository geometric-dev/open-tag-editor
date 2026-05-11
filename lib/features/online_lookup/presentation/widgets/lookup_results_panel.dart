import 'package:flutter/material.dart';

import '../../data/models/lookup_state.dart';
import '../../data/models/search_result.dart';

/// Panel displaying search results in the lookup dialog.
class LookupResultsPanel extends StatelessWidget {
  const LookupResultsPanel({
    super.key,
    required this.results,
    required this.status,
    required this.onSelectResult,
  });

  final List<SearchResult> results;
  final LookupStatus status;
  final void Function(SearchResult result) onSelectResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Text(
              '${results.length} result(s) found',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            if (status == LookupStatus.loadingTracks)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return _ResultTile(
                result: result,
                onTap: () => onSelectResult(result),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.result,
    required this.onTap,
  });

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        result.source == SearchSource.musicBrainz
            ? Icons.album
            : Icons.library_music,
        size: 20,
      ),
      title: Text(
        result.title,
        style: const TextStyle(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (result.artist != null) result.artist,
          if (result.year != null) result.year,
          if (result.country != null) result.country,
        ].join(' · '),
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.trackCount != null)
            Text(
              '${result.trackCount} tracks',
              style: const TextStyle(fontSize: 11),
            ),
          const SizedBox(width: 8),
          Chip(
            label: Text(
              result.source == SearchSource.musicBrainz ? 'MB' : 'DC',
              style: const TextStyle(fontSize: 10),
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
