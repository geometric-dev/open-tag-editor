import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cover_art_result.dart';
import '../../data/models/lookup_state.dart';
import '../../data/models/track_file_match.dart';
import '../../data/providers/lookup_state_provider.dart';

/// Panel for previewing and applying metadata from matched tracks.
class LookupApplyPanel extends ConsumerStatefulWidget {
  const LookupApplyPanel({
    super.key,
    required this.matches,
    required this.coverArt,
    required this.status,
    required this.onBack,
  });

  final List<TrackFileMatch> matches;
  final CoverArtResult? coverArt;
  final LookupStatus status;
  final VoidCallback onBack;

  @override
  ConsumerState<LookupApplyPanel> createState() => _LookupApplyPanelState();
}

class _LookupApplyPanelState extends ConsumerState<LookupApplyPanel> {
  final _selectedFields = <String>{
    'title',
    'artist',
    'trackNumber',
    'discNumber',
  };
  bool _applyCoverArt = true;
  String? _resultMessage;

  Future<void> _apply() async {
    final result = await ref.read(lookupStateProvider.notifier).applyMetadata(
          selectedFields: _selectedFields,
          applyCoverArt: _applyCoverArt && widget.coverArt != null,
        );

    if (mounted) {
      setState(() {
        _resultMessage =
            '${result.successCount} file(s) updated, ${result.failureCount} failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApplying = widget.status == LookupStatus.applying;
    final validMatches =
        widget.matches.where((m) => m.file != null && m.confidence != MatchConfidence.unmatched).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: widget.onBack,
              tooltip: 'Back to tracks',
            ),
            Text(
              '${validMatches.length} matched file(s)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: isApplying ? null : _apply,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Apply'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Field selection
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _FieldChip(
              label: 'Title',
              field: 'title',
              selected: _selectedFields,
              onChanged: (v) => setState(() {
                v ? _selectedFields.add('title') : _selectedFields.remove('title');
              }),
            ),
            _FieldChip(
              label: 'Artist',
              field: 'artist',
              selected: _selectedFields,
              onChanged: (v) => setState(() {
                v ? _selectedFields.add('artist') : _selectedFields.remove('artist');
              }),
            ),
            _FieldChip(
              label: 'Track #',
              field: 'trackNumber',
              selected: _selectedFields,
              onChanged: (v) => setState(() {
                v ? _selectedFields.add('trackNumber') : _selectedFields.remove('trackNumber');
              }),
            ),
            _FieldChip(
              label: 'Disc #',
              field: 'discNumber',
              selected: _selectedFields,
              onChanged: (v) => setState(() {
                v ? _selectedFields.add('discNumber') : _selectedFields.remove('discNumber');
              }),
            ),
            if (widget.coverArt != null)
              FilterChip(
                label: const Text('Cover Art'),
                selected: _applyCoverArt,
                onSelected: (v) => setState(() => _applyCoverArt = v),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Preview table
        Expanded(
          child: ListView.builder(
            itemCount: validMatches.length,
            itemBuilder: (context, index) {
              final match = validMatches[index];
              return _MatchPreviewTile(
                match: match,
                selectedFields: _selectedFields,
              );
            },
          ),
        ),
        // Result message
        if (_resultMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _resultMessage!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        if (isApplying)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({
    required this.label,
    required this.field,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String field;
  final Set<String> selected;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected.contains(field),
      onSelected: onChanged,
    );
  }
}

class _MatchPreviewTile extends StatelessWidget {
  const _MatchPreviewTile({
    required this.match,
    required this.selectedFields,
  });

  final TrackFileMatch match;
  final Set<String> selectedFields;

  @override
  Widget build(BuildContext context) {
    final file = match.file!;
    final track = match.track;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.filename,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (selectedFields.contains('title'))
              _FieldPreview(
                field: 'Title',
                current: file.tags['title'] ?? '',
                newValue: track.title,
              ),
            if (selectedFields.contains('artist') && track.artist != null)
              _FieldPreview(
                field: 'Artist',
                current: file.tags['artist'] ?? '',
                newValue: track.artist!,
              ),
            if (selectedFields.contains('trackNumber'))
              _FieldPreview(
                field: 'Track',
                current: file.tags['trackNumber'] ?? '',
                newValue: track.position.toString(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FieldPreview extends StatelessWidget {
  const _FieldPreview({
    required this.field,
    required this.current,
    required this.newValue,
  });

  final String field;
  final String current;
  final String newValue;

  @override
  Widget build(BuildContext context) {
    final changed = current != newValue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              field,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ),
          if (changed) ...[
            Text(
              current.isEmpty ? '(empty)' : current,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Text(' → ', style: TextStyle(fontSize: 10)),
          ],
          Text(
            newValue,
            style: TextStyle(
              fontSize: 10,
              fontWeight: changed ? FontWeight.bold : FontWeight.normal,
              color: changed ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
