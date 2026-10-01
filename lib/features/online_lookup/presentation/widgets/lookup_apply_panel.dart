import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/audio_file.dart';
import '../../data/models/cover_art_result.dart';
import '../../data/models/lookup_state.dart';
import '../../data/models/partial_match_file_entry.dart';
import '../../data/models/search_result.dart';
import '../../data/models/track_file_match.dart';
import '../../data/providers/lookup_state_provider.dart';

/// Panel for previewing and applying metadata from matched tracks.
///
/// Supports both full-match mode (all files matched) and partial-match mode
/// (some files unmatched, with per-file opt-out and confidence indicators).
class LookupApplyPanel extends ConsumerStatefulWidget {
  const LookupApplyPanel({
    super.key,
    required this.matches,
    required this.coverArt,
    required this.status,
    required this.onBack,
    this.isPartialMatch = false,
    this.allSelectedFiles = const [],
    this.optedOutPaths = const {},
    this.trackListing = const [],
  });

  final List<TrackFileMatch> matches;
  final CoverArtResult? coverArt;
  final LookupStatus status;
  final VoidCallback onBack;

  /// Whether this is a partial match (album tracks < selected files).
  final bool isPartialMatch;

  /// All selected files (for displaying unmatched files in partial mode).
  final List<AudioFile> allSelectedFiles;

  /// Set of file paths the user has opted out of metadata application.
  final Set<String> optedOutPaths;

  /// Track listing for reassignment dropdown.
  final List<TrackInfo> trackListing;

  @override
  ConsumerState<LookupApplyPanel> createState() => _LookupApplyPanelState();
}

class _LookupApplyPanelState extends ConsumerState<LookupApplyPanel> {
  final _selectedFields = <String>{
    'title',
    'artist',
    'album',
    'albumArtist',
    'year',
    'trackNumber',
    'discNumber',
  };
  bool _applyCoverArt = true;
  String? _resultMessage;

  /// Builds the list of file entries for partial match display.
  List<PartialMatchFileEntry> _buildPartialEntries() {
    final matchedPaths = <String>{};
    final entries = <PartialMatchFileEntry>[];

    // Build matched entries.
    for (final match in widget.matches) {
      if (match.file != null && match.confidence != MatchConfidence.unmatched) {
        matchedPaths.add(match.file!.path);
        entries.add(
          PartialMatchFileEntry(
            file: match.file!,
            matchedTrack: match.track,
            confidence: match.confidence,
            score: match.score,
            isOptedOut: widget.optedOutPaths.contains(match.file!.path),
          ),
        );
      }
    }

    // Build unmatched entries from allSelectedFiles.
    for (final file in widget.allSelectedFiles) {
      if (!matchedPaths.contains(file.path)) {
        entries.add(
          PartialMatchFileEntry(
            file: file,
            isOptedOut: widget.optedOutPaths.contains(file.path),
          ),
        );
      }
    }

    return entries;
  }

  Future<void> _apply() async {
    if (widget.isPartialMatch) {
      final result = await ref
          .read(lookupStateProvider.notifier)
          .applyPartialMetadata(
            selectedFields: _selectedFields,
            applyCoverArt: _applyCoverArt && widget.coverArt != null,
          );

      if (mounted) {
        setState(() {
          _resultMessage =
              '${result.successCount} file(s) updated, ${result.failureCount} failed';
        });
      }
    } else {
      final result = await ref
          .read(lookupStateProvider.notifier)
          .applyMetadata(
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
  }

  bool get _canApply {
    if (_selectedFields.isEmpty &&
        !(_applyCoverArt && widget.coverArt != null)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isApplying = widget.status == LookupStatus.applying;

    if (widget.isPartialMatch) {
      return _buildPartialMatchPanel(context, isApplying);
    }
    return _buildFullMatchPanel(context, isApplying);
  }

  Widget _buildFullMatchPanel(BuildContext context, bool isApplying) {
    final validMatches = widget.matches
        .where(
          (m) => m.file != null && m.confidence != MatchConfidence.unmatched,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          context,
          title: '${validMatches.length} matched file(s)',
          isApplying: isApplying,
        ),
        const SizedBox(height: 12),
        _buildFieldSelection(),
        const SizedBox(height: 8),
        _buildSemanticsNote(context),
        const SizedBox(height: 12),
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
        _buildResultFooter(isApplying),
      ],
    );
  }

  Widget _buildPartialMatchPanel(BuildContext context, bool isApplying) {
    final entries = _buildPartialEntries();
    final matchedCount = entries.where((e) => e.isMatched).length;
    final unmatchedCount = entries.where((e) => !e.isMatched).length;
    final totalCount = entries.length;
    final optedOutCount = widget.optedOutPaths.length;
    final applyingToCount = totalCount - optedOutCount;
    final albumArtist =
        ref.read(lookupStateProvider).selectedResult?.artist ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          context,
          title: _buildSummaryText(
            matchedCount,
            unmatchedCount,
            totalCount,
            applyingToCount,
          ),
          isApplying: isApplying,
        ),
        const SizedBox(height: 12),
        _buildFieldSelection(),
        const SizedBox(height: 8),
        _buildSemanticsNote(context),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _PartialMatchFileTile(
                entry: entry,
                selectedFields: _selectedFields,
                totalFileCount: widget.allSelectedFiles.length,
                trackListing: widget.trackListing,
                albumArtist: albumArtist,
                onOptOutToggle: () {
                  ref
                      .read(lookupStateProvider.notifier)
                      .toggleFileOptOut(entry.file.path);
                },
                onReassign: (track) {
                  ref
                      .read(lookupStateProvider.notifier)
                      .reassignTrack(entry.file.path, track);
                },
                onClearAssignment: () {
                  ref
                      .read(lookupStateProvider.notifier)
                      .clearTrackAssignment(entry.file.path);
                },
              );
            },
          ),
        ),
        _buildResultFooter(isApplying),
      ],
    );
  }

  String _buildSummaryText(
    int matchedCount,
    int unmatchedCount,
    int totalCount,
    int applyingToCount,
  ) {
    if (unmatchedCount == 0) {
      return '$totalCount file(s) matched';
    }
    return '$matchedCount of $totalCount files matched to tracks'
        ' \u2022 $unmatchedCount files will receive album info only'
        ' \u2022 Applying to $applyingToCount of $totalCount files';
  }

  /// States what applying does when the source has no value for a field.
  ///
  /// The three tag-writing surfaces state their contracts differently: the tag
  /// panel says clearing a field removes it everywhere, the extractor offers an
  /// explicit overwrite / fill-empty mode, and this panel used to state
  /// nothing -- it simply skipped fields the release page had no data for. That
  /// is the right behaviour (a missing track number should not wipe the
  /// existing one), but with no wording the user reads it as the apply having
  /// failed.
  Widget _buildSemanticsNote(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Fields with no value in the matched release are left unchanged. '
      'To remove tags instead, use Tools ▸ Clear Fields…',
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 10,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String title,
    required bool isApplying,
  }) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: widget.onBack,
          tooltip: 'Back to tracks',
        ),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: isApplying || !_canApply ? null : _apply,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildFieldSelection() {
    return Wrap(
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
            v
                ? _selectedFields.add('artist')
                : _selectedFields.remove('artist');
          }),
        ),
        _FieldChip(
          label: 'Album',
          field: 'album',
          selected: _selectedFields,
          onChanged: (v) => setState(() {
            v ? _selectedFields.add('album') : _selectedFields.remove('album');
          }),
        ),
        _FieldChip(
          label: 'Album Artist',
          field: 'albumArtist',
          selected: _selectedFields,
          onChanged: (v) => setState(() {
            v
                ? _selectedFields.add('albumArtist')
                : _selectedFields.remove('albumArtist');
          }),
        ),
        _FieldChip(
          label: 'Year',
          field: 'year',
          selected: _selectedFields,
          onChanged: (v) => setState(() {
            v ? _selectedFields.add('year') : _selectedFields.remove('year');
          }),
        ),
        _FieldChip(
          label: 'Track #',
          field: 'trackNumber',
          selected: _selectedFields,
          onChanged: (v) => setState(() {
            v
                ? _selectedFields.add('trackNumber')
                : _selectedFields.remove('trackNumber');
          }),
        ),
        _FieldChip(
          label: 'Disc #',
          field: 'discNumber',
          selected: _selectedFields,
          onChanged: (v) => setState(() {
            v
                ? _selectedFields.add('discNumber')
                : _selectedFields.remove('discNumber');
          }),
        ),
        if (widget.coverArt != null)
          FilterChip(
            label: const Text('Cover Art'),
            selected: _applyCoverArt,
            onSelected: (v) => setState(() => _applyCoverArt = v),
          ),
      ],
    );
  }

  Widget _buildResultFooter(bool isApplying) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

/// A single file row in partial match mode.
class _PartialMatchFileTile extends StatelessWidget {
  const _PartialMatchFileTile({
    required this.entry,
    required this.selectedFields,
    required this.totalFileCount,
    required this.trackListing,
    required this.albumArtist,
    required this.onOptOutToggle,
    required this.onReassign,
    required this.onClearAssignment,
  });

  final PartialMatchFileEntry entry;
  final Set<String> selectedFields;
  final int totalFileCount;
  final List<TrackInfo> trackListing;
  final String albumArtist;
  final VoidCallback onOptOutToggle;
  final void Function(TrackInfo?) onReassign;
  final VoidCallback onClearAssignment;

  @override
  Widget build(BuildContext context) {
    final isMatched = entry.isMatched;
    final opacity = isMatched ? 1.0 : 0.7;

    return Opacity(
      opacity: opacity,
      child: Card(
        color: isMatched
            ? null
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Opt-out checkbox
              Checkbox(
                value: !entry.isOptedOut,
                onChanged: (_) => onOptOutToggle(),
              ),
              // File content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filename + badges
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.file.filename,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isMatched)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Album info only',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        if (isMatched) ...[
                          _ConfidenceBadge(confidence: entry.confidence!),
                          const SizedBox(width: 4),
                          _ReassignButton(
                            trackListing: trackListing,
                            onReassign: onReassign,
                            onClear: onClearAssignment,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Metadata preview
                    if (isMatched)
                      _MatchedMetadataPreview(
                        file: entry.file,
                        track: entry.matchedTrack!,
                        selectedFields: selectedFields,
                        totalFileCount: totalFileCount,
                      )
                    else
                      _UnmatchedMetadataPreview(
                        file: entry.file,
                        selectedFields: selectedFields,
                        albumArtist: albumArtist,
                        totalFileCount: totalFileCount,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confidence badge showing match quality.
class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final MatchConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      MatchConfidence.high => ('High', Colors.green),
      MatchConfidence.medium => ('Medium', Colors.orange),
      MatchConfidence.low => ('Low', Colors.red),
      MatchConfidence.exact => ('Exact', Colors.green),
      MatchConfidence.duration => ('Duration', Colors.blue),
      _ => ('', Colors.grey),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Reassign/clear button for matched file rows.
class _ReassignButton extends StatelessWidget {
  const _ReassignButton({
    required this.trackListing,
    required this.onReassign,
    required this.onClear,
  });

  final List<TrackInfo> trackListing;
  final void Function(TrackInfo?) onReassign;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ReassignAction>(
      icon: const Icon(Icons.more_vert, size: 16),
      tooltip: 'Reassign track',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _ReassignAction.clear,
          child: Text('Clear assignment', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuDivider(),
        ...trackListing.map(
          (track) => PopupMenuItem(
            value: _ReassignAction.assign,
            onTap: () => onReassign(track),
            child: Text(
              '${track.position}. ${track.title}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
      onSelected: (action) {
        if (action == _ReassignAction.clear) {
          onClear();
        }
      },
    );
  }
}

enum _ReassignAction { clear, assign }

/// Metadata preview for a matched file (album + track fields).
class _MatchedMetadataPreview extends StatelessWidget {
  const _MatchedMetadataPreview({
    required this.file,
    required this.track,
    required this.selectedFields,
    required this.totalFileCount,
  });

  final AudioFile file;
  final TrackInfo track;
  final Set<String> selectedFields;
  final int totalFileCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            newValue: '${track.position}/$totalFileCount',
          ),
      ],
    );
  }
}

/// Metadata preview for an unmatched file (album fields only).
class _UnmatchedMetadataPreview extends StatelessWidget {
  const _UnmatchedMetadataPreview({
    required this.file,
    required this.selectedFields,
    required this.albumArtist,
    required this.totalFileCount,
  });

  final AudioFile file;
  final Set<String> selectedFields;
  final String albumArtist;
  final int totalFileCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedFields.contains('title'))
          _FieldPreview(
            field: 'Title',
            current: file.tags['title'] ?? '',
            newValue: '(no change)',
            isNoChange: true,
          ),
        if (selectedFields.contains('artist') && albumArtist.isNotEmpty)
          _FieldPreview(
            field: 'Artist',
            current: file.tags['artist'] ?? '',
            newValue: albumArtist,
          ),
        if (selectedFields.contains('trackNumber'))
          _FieldPreview(
            field: 'Track',
            current: file.tags['trackNumber'] ?? '',
            newValue: '(no change)',
            isNoChange: true,
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

/// Full-match preview tile (unchanged from original).
class _MatchPreviewTile extends StatelessWidget {
  const _MatchPreviewTile({required this.match, required this.selectedFields});

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
    this.isNoChange = false,
  });

  final String field;
  final String current;
  final String newValue;
  final bool isNoChange;

  @override
  Widget build(BuildContext context) {
    final changed = !isNoChange && current != newValue;
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
          if (isNoChange)
            Text(
              '(no change)',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          else if (changed) ...[
            Flexible(
              child: Text(
                current.isEmpty ? '(empty)' : current,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                  decoration: TextDecoration.lineThrough,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Text(' \u2192 ', style: TextStyle(fontSize: 10)),
            Flexible(
              child: Text(
                newValue,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            Flexible(
              child: Text(
                newValue,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
