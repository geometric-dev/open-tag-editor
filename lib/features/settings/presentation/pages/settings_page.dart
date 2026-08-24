import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../online_lookup/data/providers/lookup_settings_provider.dart';
import '../../data/models/general_settings.dart';
import '../../data/models/id3v2_version.dart';
import '../../data/models/tag_encoding.dart';
import '../../data/providers/settings_providers.dart';

/// The category tabs shown in the settings sidebar.
enum _SettingsCategory {
  general('General'),
  fileProtection('File Protection'),
  tagWriting('Tag Writing'),
  renaming('File Renaming'),
  onlineLookup('Online Lookup');

  const _SettingsCategory(this.label);
  final String label;
}

/// Application settings dialog with a desktop-native two-pane layout.
///
/// Use [SettingsDialog.show] to open the dialog from anywhere in the app.
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  /// Opens the settings dialog as a modal overlay.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  _SettingsCategory _selected = _SettingsCategory.general;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 720,
          maxHeight: 520,
        ),
        child: Column(
          children: [
            // --- Title bar ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Text('Settings', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 16,
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
            // --- Body: sidebar + content ---
            Expanded(
              child: Row(
                children: [
                  // Left sidebar
                  SizedBox(
                    width: 170,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: _SettingsCategory.values.map((category) {
                          final isSelected = category == _selected;
                          return _SidebarItem(
                            label: category.label,
                            isSelected: isSelected,
                            onTap: () => setState(() => _selected = category),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // Right content pane
                  Expanded(
                    child: _buildContent(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    switch (_selected) {
      case _SettingsCategory.general:
        return _GeneralPane(ref: ref);
      case _SettingsCategory.fileProtection:
        return _FileProtectionPane(ref: ref);
      case _SettingsCategory.tagWriting:
        return _TagWritingPane(ref: ref);
      case _SettingsCategory.renaming:
        return _RenamingPane(ref: ref);
      case _SettingsCategory.onlineLookup:
        return _OnlineLookupPane(ref: ref);
    }
  }
}

/// A single item in the settings sidebar.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content panes
// ---------------------------------------------------------------------------

class _GeneralPane extends StatelessWidget {
  const _GeneralPane({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(generalSettingsProvider);

    return _SettingsPane(
      title: 'General',
      onReset: () =>
          ref.read(generalSettingsProvider.notifier).resetToDefaults(),
      children: [
        _CheckboxRow(
          label: 'Reopen last folder on startup',
          subtitle:
              'Automatically reload the most recent folder when the app launches',
          value: settings.reopenLastFolder,
          onChanged: (v) =>
              ref.read(generalSettingsProvider.notifier).setReopenLastFolder(v),
        ),
        _TextFieldRow(
          label: 'Large folder warning threshold',
          subtitle: 'Show warning when scanning more than this many files',
          value: settings.fileCountThreshold.toString(),
          onChanged: (v) => ref
              .read(generalSettingsProvider.notifier)
              .setFileCountThreshold(int.tryParse(v) ?? 500),
        ),
        _ThemeModeRow(
          value: settings.themeMode,
          onChanged: (mode) =>
              ref.read(generalSettingsProvider.notifier).setThemeMode(mode),
        ),
      ],
    );
  }
}

class _FileProtectionPane extends StatelessWidget {
  const _FileProtectionPane({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(generalSettingsProvider);

    return _SettingsPane(
      title: 'File Protection',
      onReset: () {
        ref.read(generalSettingsProvider.notifier).setBackupEnabled(true);
        ref
            .read(generalSettingsProvider.notifier)
            .setPreserveTimestamp(false);
      },
      children: [
        _CheckboxRow(
          label: 'Create backup before writing',
          subtitle: 'Saves a .bak copy of files before modifying tags',
          value: settings.backupEnabled,
          onChanged: (v) =>
              ref.read(generalSettingsProvider.notifier).setBackupEnabled(v),
        ),
        _CheckboxRow(
          label: 'Preserve file modification time',
          subtitle:
              'Keep original file timestamp when saving tags (don’t change file time)',
          value: settings.preserveTimestamp,
          onChanged: (v) => ref
              .read(generalSettingsProvider.notifier)
              .setPreserveTimestamp(v),
        ),
      ],
    );
  }
}

class _TagWritingPane extends StatelessWidget {
  const _TagWritingPane({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(tagWritingSettingsProvider);

    return _SettingsPane(
      title: 'Tag Writing',
      onReset: () =>
          ref.read(tagWritingSettingsProvider.notifier).resetToDefaults(),
      children: [
        _DropdownRow<Id3v2Version>(
          label: 'Default ID3v2 version',
          value: settings.id3v2Version,
          items: Id3v2Version.values,
          itemLabel: (v) => v.displayName,
          onChanged: (v) =>
              ref.read(tagWritingSettingsProvider.notifier).setId3v2Version(v),
        ),
        _CheckboxRow(
          label: 'Write ID3v1 tags',
          subtitle: 'Also write legacy ID3v1 tags to MP3 files',
          value: settings.writeId3v1,
          onChanged: (v) =>
              ref.read(tagWritingSettingsProvider.notifier).setWriteId3v1(v),
        ),
        _DropdownRow<TagEncoding>(
          label: 'Default encoding',
          value: settings.encoding,
          items: TagEncoding.values,
          itemLabel: (v) => v.displayName,
          onChanged: (v) =>
              ref.read(tagWritingSettingsProvider.notifier).setEncoding(v),
        ),
      ],
    );
  }
}

class _RenamingPane extends StatelessWidget {
  const _RenamingPane({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(renamingSettingsProvider);

    return _SettingsPane(
      title: 'File Renaming',
      onReset: () =>
          ref.read(renamingSettingsProvider.notifier).resetToDefaults(),
      children: [
        _TextFieldRow(
          label: 'Default rename pattern',
          value: settings.defaultPattern,
          onChanged: (v) =>
              ref.read(renamingSettingsProvider.notifier).setDefaultPattern(v),
        ),
        _CheckboxRow(
          label: 'Preview before renaming',
          subtitle: 'Always show preview before executing renames',
          value: settings.previewBeforeRenaming,
          onChanged: (v) => ref
              .read(renamingSettingsProvider.notifier)
              .setPreviewBeforeRenaming(v),
        ),
      ],
    );
  }
}

class _OnlineLookupPane extends StatelessWidget {
  const _OnlineLookupPane({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(lookupSettingsProvider);

    return _SettingsPane(
      title: 'Online Lookup',
      onReset: () =>
          ref.read(lookupSettingsProvider.notifier).resetToDefaults(),
      children: [
        _TextFieldRow(
          label: 'Discogs Personal Access Token',
          value: settings.discogsToken,
          onChanged: (v) =>
              ref.read(lookupSettingsProvider.notifier).setDiscogsToken(v),
          obscure: true,
        ),
        _TextFieldRow(
          label: 'Path to fpcalc binary',
          value: settings.fpcalcPath,
          onChanged: (v) =>
              ref.read(lookupSettingsProvider.notifier).setFpcalcPath(v),
        ),
        _CheckboxRow(
          label: 'Auto-fetch album art',
          subtitle:
              'Automatically download cover art when a release is selected',
          value: settings.autoFetchCoverArt,
          onChanged: (v) =>
              ref.read(lookupSettingsProvider.notifier).setAutoFetchCoverArt(v),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

/// Container for a settings content pane with a title and flat row list.
class _SettingsPane extends StatelessWidget {
  const _SettingsPane({
    required this.title,
    required this.children,
    this.onReset,
  });

  final String title;
  final List<Widget> children;

  /// When provided, a "Reset to Defaults" button is shown at the bottom of the
  /// pane. Tapping it shows a confirmation dialog before invoking the callback.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ...children,
        if (onReset != null) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _confirmReset(context),
              child: const Text('Reset to Defaults'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'Reset all settings in this category to defaults?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onReset!();
    }
  }
}

/// A segmented control for choosing the application theme mode.
class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  'Applies immediately',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  icon: Icon(Icons.settings_suggest_outlined, size: 16),
                  label: Text('System', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined, size: 16),
                  label: Text('Light', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined, size: 16),
                  label: Text('Dark', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.first),
              showSelectedIcon: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat row with a checkbox, label, and optional subtitle.
class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row with a label and an inline dropdown.
class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<T>(
              initialValue: value,
              isDense: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        itemLabel(item),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A row with a label and an inline text field that commits on focus loss.
class _TextFieldRow extends StatefulWidget {
  const _TextFieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.obscure = false,
  });

  final String label;
  final String? subtitle;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscure;

  @override
  State<_TextFieldRow> createState() => _TextFieldRowState();
}

class _TextFieldRowState extends State<_TextFieldRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _TextFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      final trimmed = _controller.text.trim();
      if (trimmed != widget.value) {
        widget.onChanged(trimmed);
      }
    }
  }

  void _onSubmitted(String text) {
    final trimmed = text.trim();
    if (trimmed != widget.value) {
      widget.onChanged(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              obscureText: widget.obscure,
              style: theme.textTheme.bodyMedium,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onSubmitted: _onSubmitted,
            ),
          ),
        ],
      ),
    );
  }

  String get label => widget.label;
}
