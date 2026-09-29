import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/error_handling/utils/error_entry_factory.dart';
import '../../../../shared/models/audio_file.dart';
import '../../../../shared/services/tag_sync_service.dart';
import '../../tag_editor/data/providers/editor_state_provider.dart';
import '../../tag_editor/data/providers/service_providers.dart';

/// Direction for the tag synchronization wizard.
enum _SyncDirection {
  v2toV1(
    'Copy visible tags → ID3v1',
    'Rewrites the legacy ID3v1 block from the current ID3v2 data.',
  ),
  v1toV2(
    'Fill empty tags ← ID3v1',
    'Imports ID3v1 values into fields that are currently empty. '
        'Existing v2 values are never overwritten.',
  );

  const _SyncDirection(this.title, this.description);

  final String title;
  final String description;
}

/// Modal wizard reproducing Tag&Rename's "Tags synchronization" dialog.
///
/// Shows how many MP3s are selected, lets the user pick a direction, and
/// previews what will change before executing. Non-MP3 files in the
/// selection are reported as skipped.
class TagSyncDialog extends ConsumerStatefulWidget {
  const TagSyncDialog({super.key});

  @override
  ConsumerState<TagSyncDialog> createState() => _TagSyncDialogState();
}

class _TagSyncDialogState extends ConsumerState<TagSyncDialog> {
  _SyncDirection _direction = _SyncDirection.v2toV1;
  bool _running = false;
  TagSyncResult? _result;

  List<AudioFile> get _selected => ref.read(selectedFilesProvider);

  int get _mp3Count =>
      _selected.where((f) => f.path.toLowerCase().endsWith('.mp3')).length;

  /// Preview rows for the fill direction: file + which v1 fields would be
  /// brought in. Only computed for up to 5 files to keep it cheap.
  List<(String filename, List<String> filledFields)> get _previewFill {
    final rows = <(String, List<String>)>[];
    for (final file in _selected) {
      if (!file.path.toLowerCase().endsWith('.mp3')) continue;
      final v1 = Id3v1Codec.readFromFile(file.path);
      if (v1 == null) continue;

      final filled = <String>[];
      for (final entry in v1.entries) {
        final current = file.tags[entry.key];
        if ((current == null || current.isEmpty) && entry.value.isNotEmpty) {
          filled.add(entry.key);
        }
      }
      if (filled.isNotEmpty) {
        rows.add((file.filename, filled));
      }
      if (rows.length >= 5) break;
    }
    return rows;
  }

  Future<void> _execute() async {
    setState(() => _running = true);
    final status = ref.read(statusMessageProvider.notifier);
    status.state = 'Synchronizing tags...';

    try {
      final service = TagSyncService(tagWriter: ref.read(tagWriterProvider));
      final result = _direction == _SyncDirection.v2toV1
          ? await service.syncToId3v1(_selected)
          : await service.syncFromId3v1(_selected);

      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
      });

      status.state =
          'Tag sync: ${result.updatedCount} updated, '
          '${result.skippedCount} skipped';

      if (result.failures.isNotEmpty) {
        ref.read(errorLogProvider.notifier).addEntries([
          for (final f in result.failures)
            ErrorEntryFactory.fromLookupFailure(
              summary: f.path,
              message: f.error ?? 'Unknown sync error',
            ),
        ]);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tag sync failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mp3Count = _mp3Count;
    final previewRows = _direction == _SyncDirection.v1toV2 && _result == null
        ? _previewFill
        : const <(String, List<String>)>[];

    return AlertDialog(
      title: const Text('Tags Synchronization'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_mp3Count of ${_selected.length} selected file(s) are MP3.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            RadioGroup<_SyncDirection>(
              groupValue: _direction,
              onChanged: _running
                  ? (_) {}
                  : (v) => setState(() => _direction = v!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._SyncDirection.values.map(
                    (d) => RadioListTile<_SyncDirection>(
                      value: d,
                      title: Text(d.title, style: theme.textTheme.bodyMedium),
                      subtitle: Text(
                        d.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            // Fill-direction preview
            if (_direction == _SyncDirection.v1toV2 && _result == null) ...[
              const SizedBox(height: 8),
              Text('Preview', style: theme.textTheme.labelMedium),
              if (previewRows.isEmpty)
                Text(
                  'No empty fields would be filled from ID3v1.',
                  style: theme.textTheme.bodySmall,
                )
              else
                ...previewRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: row.$1),
                          const TextSpan(text: ' → '),
                          TextSpan(
                            text: row.$2.join(', '),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
            ],
            // Results
            if (_result != null) ...[
              const Divider(height: 24),
              Text(
                'Done: ${_result!.updatedCount} updated, '
                '${_result!.skippedCount} skipped.',
                style: theme.textTheme.bodyMedium,
              ),
              if (_result!.failures.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_result!.failures.length} failed — see error log.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_result != null ? 'Close' : 'Cancel'),
        ),
        if (_result == null)
          FilledButton(
            onPressed: mp3Count == 0 || _running ? null : _execute,
            child: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Synchronize'),
          ),
      ],
    );
  }
}
