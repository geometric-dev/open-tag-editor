import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/error_entry.dart';
import '../models/operation_type.dart';
import '../providers/error_providers.dart';
import '../providers/retry_provider.dart';

/// Bottom panel displaying the session error log as a scrollable list.
///
/// Shows a header with title, error count badge, "Retry All Failed" and
/// "Clear" actions. The body renders [ErrorEntry] rows with file name,
/// operation type chip, error message, timestamp, and per-row retry button.
class ErrorPanel extends ConsumerWidget {
  const ErrorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorLogState = ref.watch(errorLogProvider);
    final isRetrying = ref.watch(isRetryingProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final entries = errorLogState.entries;

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          _buildHeader(context, ref, entries, isRetrying),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      'No errors recorded',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemExtent: 40,
                    itemBuilder: (context, index) => _ErrorRow(
                      entry: entries[index],
                      isRetrying: isRetrying,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    List<ErrorEntry> entries,
    bool isRetrying,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('Errors', style: textTheme.titleSmall),
          const SizedBox(width: 8),
          // Error count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${entries.length}',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onError,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: isRetrying || entries.isEmpty
                ? null
                : () => ref.read(retryServiceProvider).retryAll(),
            child: const Text('Retry All Failed', style: TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: entries.isEmpty
                ? null
                : () => ref.read(errorLogProvider.notifier).clear(),
            child: const Text('Clear', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

/// A single row in the error panel displaying one [ErrorEntry].
class _ErrorRow extends ConsumerWidget {
  const _ErrorRow({
    required this.entry,
    required this.isRetrying,
  });

  /// The error entry to display.
  final ErrorEntry entry;

  /// Whether a retry operation is in progress.
  final bool isRetrying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // File name (bold)
          SizedBox(
            width: 160,
            child: Text(
              entry.fileName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Operation type chip
          _OperationChip(operationType: entry.operationType),
          const SizedBox(width: 8),
          // Error message
          Expanded(
            child: Text(
              entry.errorMessage,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Timestamp (HH:mm:ss)
          Text(
            _formatTimestamp(entry.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          // Retry button
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            iconSize: 16,
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            padding: EdgeInsets.zero,
            onPressed: isRetrying
                ? null
                : () => ref.read(retryServiceProvider).retrySingle(entry.id),
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// A small chip displaying the operation type.
class _OperationChip extends StatelessWidget {
  const _OperationChip({required this.operationType});

  final OperationType operationType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        operationType.name,
        style: TextStyle(
          fontSize: 10,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
