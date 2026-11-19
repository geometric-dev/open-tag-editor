import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/rename_profile.dart';
import '../../data/rename_profile_notifier.dart';

/// Settings section for managing rule-based rename profiles.
///
/// Each profile pairs a mask pattern with conditions; the rename dialog picks
/// the first profile whose conditions match the current selection. This is the
/// no-scripting way to get per-release-shape naming (Standard / Various
/// Artists / Compilation / multi-disc).
class RenameProfilesSection extends ConsumerWidget {
  const RenameProfilesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(renameProfileProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Rename profiles',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _editProfile(context, ref, null),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Applied top-to-bottom: the first profile whose conditions match the '
          'selection wins. Put specific profiles above general ones.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (profiles.isEmpty)
          Text(
            'No profiles defined. The rename dialog falls back to the preset '
            'or default pattern.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (var i = 0; i < profiles.length; i++)
            _ProfileRow(
              index: i,
              profile: profiles[i],
              canMoveUp: i > 0,
              canMoveDown: i < profiles.length - 1,
            ),
      ],
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    RenameProfile? profile,
  ) async {
    final result = await showDialog<RenameProfile>(
      context: context,
      builder: (_) => _ProfileEditorDialog(profile: profile),
    );
    if (result == null) return;
    final notifier = ref.read(renameProfileProvider.notifier);
    if (profile == null) {
      await notifier.add(result);
    } else {
      final index = ref.read(renameProfileProvider).indexOf(profile);
      if (index >= 0) await notifier.update(index, result);
    }
  }
}

class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({
    required this.index,
    required this.profile,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  final int index;
  final RenameProfile profile;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(renameProfileProvider.notifier);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: canMoveUp ? () => notifier.moveUp(index) : null,
              icon: const Icon(Icons.arrow_upward, size: 16),
              tooltip: 'Move up (higher priority)',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: canMoveDown ? () => notifier.moveDown(index) : null,
              icon: const Icon(Icons.arrow_downward, size: 16),
              tooltip: 'Move down (lower priority)',
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _describe(profile),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.edit, size: 16),
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_outline, size: 16),
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  String _describe(RenameProfile profile) {
    String describeCondition(ProfileCondition c) =>
        '${c.field} ${c.operator.label}'
        '${c.value.isEmpty ? '' : ' "${c.value}"'}';

    final conditionText = profile.isCatchAll
        ? 'always'
        : profile.conditionGroups
              .map((g) => g.map(describeCondition).join(' and '))
              .join('  OR  ');
    return '$conditionText → ${profile.pattern}';
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<RenameProfile>(
      context: context,
      builder: (_) => _ProfileEditorDialog(profile: profile),
    );
    if (result == null) return;
    final notifier = ref.read(renameProfileProvider.notifier);
    final currentIndex = ref.read(renameProfileProvider).indexOf(profile);
    if (currentIndex >= 0) await notifier.update(currentIndex, result);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile'),
        content: Text("Delete profile '${profile.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final notifier = ref.read(renameProfileProvider.notifier);
      final currentIndex = ref.read(renameProfileProvider).indexOf(profile);
      if (currentIndex >= 0) await notifier.delete(currentIndex);
    }
  }
}

/// Dialog to create or edit a single [RenameProfile].
class _ProfileEditorDialog extends ConsumerStatefulWidget {
  const _ProfileEditorDialog({this.profile});

  final RenameProfile? profile;

  @override
  ConsumerState<_ProfileEditorDialog> createState() =>
      _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends ConsumerState<_ProfileEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _patternController;
  late List<List<ProfileCondition>> _groups;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _patternController = TextEditingController(text: profile?.pattern ?? '');
    // Start with one group so there is always something to edit; a brand new
    // profile gets a single empty group (one condition row).
    final existing = profile?.conditionGroups ?? const [];
    _groups = existing.isEmpty
        ? [
            [
              const ProfileCondition(
                field: 'albumArtist',
                operator: ProfileOperator.equals,
                value: '',
              ),
            ],
          ]
        : existing.map((g) => List.of(g)).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.profile != null;
    final canSave = _nameController.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Profile' : 'Add Profile'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern',
                  hintText: '%artist - %album/%track - %title',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Match any of these (OR)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addGroup,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add alternative'),
                  ),
                ],
              ),
              Text(
                'Within a group all conditions must match (AND); the profile '
                'matches when any group matches. Leave all groups empty for a '
                'catch-all. One pattern, many alternatives — e.g. AlbumArtist '
                'is OST or VA or Soundtrack.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (var g = 0; g < _groups.length; g++)
                _ConditionGroupCard(
                  groupIndex: g,
                  group: _groups[g],
                  canRemove: _groups.length > 1,
                  onAddCondition: () => _addCondition(g),
                  onRemoveGroup: () => setState(() => _groups.removeAt(g)),
                  onChangedCondition: (ci, c) =>
                      setState(() => _groups[g][ci] = c),
                  onRemoveCondition: (ci) =>
                      setState(() => _groups[g].removeAt(ci)),
                ),
              if (_groups.isEmpty)
                Text(
                  'No groups — matches every selection.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave
              ? () {
                  final name = _nameController.text.trim();
                  final pattern = _patternController.text;
                  final base = widget.profile;
                  // Drop empty groups (an empty group would match anything,
                  // which is almost never what the user means).
                  final groups = _groups
                      .where((g) => g.isNotEmpty)
                      .map((g) => List.of(g))
                      .toList();
                  Navigator.of(context).pop(
                    RenameProfile(
                      name: name,
                      pattern: pattern,
                      conditionGroups: groups,
                      isBuiltIn: base?.isBuiltIn ?? false,
                    ),
                  );
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _addCondition(int groupIndex) {
    setState(() {
      _groups[groupIndex].add(
        const ProfileCondition(
          field: 'albumArtist',
          operator: ProfileOperator.equals,
          value: '',
        ),
      );
    });
  }

  void _addGroup() {
    setState(() {
      _groups.add([
        const ProfileCondition(
          field: 'albumArtist',
          operator: ProfileOperator.equals,
          value: '',
        ),
      ]);
    });
  }
}

class _ConditionGroupCard extends StatelessWidget {
  const _ConditionGroupCard({
    required this.groupIndex,
    required this.group,
    required this.canRemove,
    required this.onAddCondition,
    required this.onRemoveGroup,
    required this.onChangedCondition,
    required this.onRemoveCondition,
  });

  final int groupIndex;
  final List<ProfileCondition> group;
  final bool canRemove;
  final VoidCallback onAddCondition;
  final VoidCallback onRemoveGroup;
  final void Function(int conditionIndex, ProfileCondition) onChangedCondition;
  final void Function(int conditionIndex) onRemoveCondition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  groupIndex == 0 ? 'Match ALL of:' : 'OR — match ALL of:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    onPressed: onRemoveGroup,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    tooltip: 'Remove this alternative',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            for (var i = 0; i < group.length; i++)
              _ConditionRow(
                index: i,
                condition: group[i],
                onChanged: (c) => onChangedCondition(i, c),
                onRemove: () => onRemoveCondition(i),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddCondition,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add condition'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionRow extends StatefulWidget {
  const _ConditionRow({
    required this.index,
    required this.condition,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final ProfileCondition condition;
  final ValueChanged<ProfileCondition> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ConditionRow> createState() => _ConditionRowState();
}

class _ConditionRowState extends State<_ConditionRow> {
  late final TextEditingController _fieldController;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _fieldController = TextEditingController(text: widget.condition.field);
    _valueController = TextEditingController(text: widget.condition.value);
  }

  @override
  void dispose() {
    _fieldController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final condition = widget.condition;
    final valueEnabled =
        condition.operator != ProfileOperator.isSet &&
        condition.operator != ProfileOperator.isNotSet;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Field',
                hintText: 'albumArtist',
                isDense: true,
              ),
              controller: _fieldController,
              onChanged: (v) => widget.onChanged(condition.copyWith(field: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<ProfileOperator>(
              initialValue: condition.operator,
              decoration: const InputDecoration(
                labelText: 'Operator',
                isDense: true,
              ),
              items: [
                for (final op in ProfileOperator.values)
                  DropdownMenuItem(value: op, child: Text(op.label)),
              ],
              onChanged: (v) {
                if (v != null) {
                  widget.onChanged(condition.copyWith(operator: v));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Value',
                isDense: true,
              ),
              controller: _valueController,
              enabled: valueEnabled,
              onChanged: (v) => widget.onChanged(condition.copyWith(value: v)),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove condition',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
