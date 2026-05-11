import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/tag_editor/data/providers/service_providers.dart';
import '../../../online_lookup/data/providers/lookup_settings_provider.dart';

/// Application settings page.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _showTextInputDialog(
    BuildContext context, {
    required String title,
    required String currentValue,
    required void Function(String) onSave,
  }) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter value...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'General',
            children: [
              SwitchListTile(
                title: const Text('Confirm before saving'),
                subtitle: const Text(
                  'Show a confirmation dialog before writing tag changes',
                ),
                value: true,
                onChanged: (value) {
                  // TODO: Implement setting
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'File Protection',
            children: [
              SwitchListTile(
                title: const Text('Create backup before writing'),
                subtitle: const Text(
                  'Saves a .bak copy of files before modifying tags',
                ),
                value: ref.watch(backupEnabledProvider),
                onChanged: (value) {
                  ref.read(backupEnabledProvider.notifier).state = value;
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'Tag Writing',
            children: [
              ListTile(
                title: const Text('Default ID3v2 version'),
                subtitle: const Text('ID3v2.4'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show version picker
                },
              ),
              SwitchListTile(
                title: const Text('Write ID3v1 tags'),
                subtitle: const Text(
                  'Also write legacy ID3v1 tags to MP3 files',
                ),
                value: false,
                onChanged: (value) {
                  // TODO: Implement setting
                },
              ),
              ListTile(
                title: const Text('Default encoding'),
                subtitle: const Text('UTF-8'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show encoding picker
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'File Renaming',
            children: [
              ListTile(
                title: const Text('Default rename pattern'),
                subtitle: const Text('%artist% - %title%'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show pattern editor
                },
              ),
              SwitchListTile(
                title: const Text('Preview before renaming'),
                subtitle: const Text(
                  'Always show preview before executing renames',
                ),
                value: true,
                onChanged: (value) {
                  // TODO: Implement setting
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'Online Lookup',
            children: [
              ListTile(
                title: const Text('Discogs Token'),
                subtitle: Text(
                  ref.watch(lookupSettingsProvider).isDiscogsConfigured
                      ? 'Configured'
                      : 'Not configured',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTextInputDialog(
                  context,
                  title: 'Discogs Personal Access Token',
                  currentValue: ref.read(lookupSettingsProvider).discogsToken,
                  onSave: (value) => ref
                      .read(lookupSettingsProvider.notifier)
                      .setDiscogsToken(value),
                ),
              ),

              ListTile(
                title: const Text('fpcalc Path'),
                subtitle: Text(
                  ref.watch(lookupSettingsProvider).fpcalcPath.isEmpty
                      ? 'Not configured'
                      : ref.watch(lookupSettingsProvider).fpcalcPath,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTextInputDialog(
                  context,
                  title: 'Path to fpcalc binary',
                  currentValue: ref.read(lookupSettingsProvider).fpcalcPath,
                  onSave: (value) => ref
                      .read(lookupSettingsProvider.notifier)
                      .setFpcalcPath(value),
                ),
              ),
              SwitchListTile(
                title: const Text('Auto-fetch album art'),
                subtitle: const Text(
                  'Automatically download cover art when a release is selected',
                ),
                value: ref.watch(lookupSettingsProvider).autoFetchCoverArt,
                onChanged: (value) => ref
                    .read(lookupSettingsProvider.notifier)
                    .setAutoFetchCoverArt(value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        Card(
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
