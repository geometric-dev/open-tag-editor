import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../features/error_handling/providers/error_providers.dart';
import '../../../../features/error_handling/utils/error_entry_factory.dart';
import '../../../../shared/models/audio_file.dart';
import '../../../../shared/providers/tag_field_validation_provider.dart';
import '../../../../shared/services/taglib/taglib_types.dart';
import '../../../../shared/widgets/validation_indicator.dart';
import '../../../album_art/data/image_validator.dart';
import '../../../album_art/data/mixed_art_detector.dart';
import '../../../album_art/data/models/batch_progress.dart';
import '../../../album_art/data/providers/album_art_providers.dart';
import '../../../album_art/presentation/widgets/batch_progress_overlay.dart';
import '../../../album_art/presentation/widgets/drop_zone_wrapper.dart';
import '../../../album_art/presentation/widgets/image_preview_modal.dart';
import '../../data/commands/tag_edit_command.dart';
import '../../data/providers/editor_state_provider.dart'
    show
        TagPanelTab,
        selectedFilesProvider,
        statusMessageProvider,
        tagPanelActiveTabProvider;
import '../../data/providers/file_list_provider.dart' show fileListProvider;
import '../../data/providers/service_providers.dart'
    show tagSaveServiceProvider;

/// Panel for editing tag fields of the selected file(s).
///
/// Uses a flat, desktop-native layout with compact segmented tabs
/// instead of Material TabBar.
class TagEditPanel extends ConsumerStatefulWidget {
  const TagEditPanel({super.key});

  @override
  ConsumerState<TagEditPanel> createState() => _TagEditPanelState();
}

class _TagEditPanelState extends ConsumerState<TagEditPanel> {
  Future<void> _saveChanges(BuildContext context, WidgetRef ref) async {
    final statusNotifier = ref.read(statusMessageProvider.notifier);

    statusNotifier.state = 'Saving...';

    final summary = await ref.read(tagSaveServiceProvider).saveAllModified();

    if (summary == null) {
      statusNotifier.state = 'No changes to save';
      return;
    }

    if (summary.failureCount > 0) {
      // Surface failures in the error log (parity with toolbar/Ctrl+S).
      final entries = ErrorEntryFactory.fromWriteResults(
        summary.results,
        summary.attemptedTags,
      );
      ref.read(errorLogProvider.notifier).addEntries(entries);
      statusNotifier.state =
          'Saved ${summary.successCount} file(s), ${summary.failureCount} failed';
    } else {
      statusNotifier.state = 'Saved ${summary.successCount} file(s)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final selectedFiles = ref.watch(selectedFilesProvider);
    final activeTab = ref.watch(tagPanelActiveTabProvider);

    if (selectedFiles.isEmpty) {
      return Center(
        child: Text(
          'Select one or more files to edit tags',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    return Column(
      children: [
        // --- Selection header ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.audio_file, size: 14, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedFiles.length == 1
                      ? selectedFiles.first.filename
                      : '${selectedFiles.length} files selected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selectedFiles.any((f) => f.isModified))
                _CompactButton(
                  label: 'Save',
                  icon: Icons.save,
                  onPressed: () => _saveChanges(context, ref),
                ),
            ],
          ),
        ),
        // --- Tab row ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              _TabButton(
                label: 'Tags',
                isActive: activeTab == TagPanelTab.tags,
                onTap: () =>
                    ref.read(tagPanelActiveTabProvider.notifier).state =
                        TagPanelTab.tags,
              ),
              _TabButton(
                label: 'Album Art',
                isActive: activeTab == TagPanelTab.albumArt,
                onTap: () =>
                    ref.read(tagPanelActiveTabProvider.notifier).state =
                        TagPanelTab.albumArt,
              ),
              _TabButton(
                label: 'File Info',
                isActive: activeTab == TagPanelTab.fileInfo,
                onTap: () =>
                    ref.read(tagPanelActiveTabProvider.notifier).state =
                        TagPanelTab.fileInfo,
              ),
            ],
          ),
        ),
        // --- Content ---
        Expanded(child: _buildTabContent(activeTab, selectedFiles)),
      ],
    );
  }

  Widget _buildTabContent(
    TagPanelTab activeTab,
    List<AudioFile> selectedFiles,
  ) {
    switch (activeTab) {
      case TagPanelTab.tags:
        return _TagFieldsTab(selectedFiles: selectedFiles);
      case TagPanelTab.albumArt:
        return _AlbumArtTab(selectedFiles: selectedFiles);
      case TagPanelTab.fileInfo:
        return _FileInfoTab(selectedFiles: selectedFiles);
    }
  }
}

/// A compact flat tab button for the panel tab row.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isActive
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact button used in the panel header (e.g. Save).
class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primary,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: colorScheme.onPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tags tab
// ---------------------------------------------------------------------------

class _TagFieldsTab extends ConsumerStatefulWidget {
  const _TagFieldsTab({required this.selectedFiles});

  final List<AudioFile> selectedFiles;

  @override
  ConsumerState<_TagFieldsTab> createState() => _TagFieldsTabState();
}

class _TagFieldsTabState extends ConsumerState<_TagFieldsTab> {
  final _controllers = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};

  static const _fields = [
    'title',
    'artist',
    'albumArtist',
    'album',
    'year',
    'genre',
    'trackNumber',
    'discNumber',
    'composer',
    'comment',
    'conductor',
    'publisher',
    'bpm',
  ];

  static const _fieldLabels = {
    'title': 'Title',
    'artist': 'Artist',
    'albumArtist': 'Album Artist',
    'album': 'Album',
    'year': 'Year',
    'genre': 'Genre',
    'trackNumber': 'Track #',
    'discNumber': 'Disc #',
    'composer': 'Composer',
    'comment': 'Comment',
    'conductor': 'Conductor',
    'publisher': 'Publisher',
    'bpm': 'BPM',
  };

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field] = TextEditingController();
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (!focusNode.hasFocus) {
          final currentText = _controllers[field]!.text;
          if (currentText != _getFieldValue(field)) {
            _onFieldChanged(field, currentText);
          }
        }
      });
      _focusNodes[field] = focusNode;
    }
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _TagFieldsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    for (final field in _fields) {
      if (_focusNodes[field]!.hasFocus) continue;
      final value = _getFieldValue(field);
      final controller = _controllers[field]!;
      if (controller.text != value) {
        controller.text = value;
      }
    }
  }

  String _getFieldValue(String field) {
    if (widget.selectedFiles.isEmpty) return '';
    if (widget.selectedFiles.length == 1) {
      return widget.selectedFiles.first.tags[field] ?? '';
    }

    final values = widget.selectedFiles.map((f) => f.tags[field] ?? '').toSet();
    if (values.length == 1) return values.first;
    return '';
  }

  void _onFieldChanged(String field, String newValue) {
    final files = widget.selectedFiles;
    final filePaths = files.map((f) => f.path).toList();
    final previousValues = <String, String?>{};
    for (final file in files) {
      previousValues[file.path] = file.tags[field];
    }

    final command = TagEditCommand(
      fileListNotifier: ref.read(fileListProvider.notifier),
      filePaths: filePaths,
      fieldName: field,
      newValue: newValue,
      previousValues: previousValues,
    );

    ref.read(undoRedoProvider.notifier).execute(command);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMixed = widget.selectedFiles.length > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMixed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Editing ${widget.selectedFiles.length} files. '
                'Empty fields will not be changed.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          _buildField('title'),
          _buildField('artist'),
          _buildField('albumArtist'),
          _buildField('album'),
          Row(
            children: [
              Expanded(child: _buildField('year')),
              const SizedBox(width: 8),
              Expanded(child: _buildField('genre')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildField('trackNumber')),
              const SizedBox(width: 8),
              Expanded(child: _buildField('discNumber')),
            ],
          ),
          _buildField('composer'),
          _buildField('conductor'),
          _buildField('publisher'),
          Row(
            children: [
              Expanded(child: _buildField('bpm')),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),
          _buildField('comment'),
        ],
      ),
    );
  }

  Widget _buildField(String field) {
    final isMixed = widget.selectedFiles.length > 1;
    final values = widget.selectedFiles.map((f) => f.tags[field] ?? '').toSet();
    final hasMultipleValues = isMixed && values.length > 1;

    final validate = ref.watch(tagFieldValidationProvider);
    final currentValue = _controllers[field]?.text ?? '';
    final tagFormat = widget.selectedFiles.firstOrNull?.tagFormat;
    final issues = validate(
      field: field,
      value: currentValue,
      tagFormat: tagFormat,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              _fieldLabels[field] ?? field,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controllers[field],
              focusNode: _focusNodes[field],
              decoration: InputDecoration(
                hintText: hasMultipleValues ? '<mixed>' : null,
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                suffixIcon: ValidationIndicator(issues: issues),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
              ),
              style: const TextStyle(fontSize: 12),
              onSubmitted: (value) => _onFieldChanged(field, value),
              onChanged: (_) => setState(() {}),
              onEditingComplete: () {
                _onFieldChanged(field, _controllers[field]!.text);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Album Art tab
// ---------------------------------------------------------------------------

class _AlbumArtTab extends ConsumerStatefulWidget {
  const _AlbumArtTab({required this.selectedFiles});

  final List<AudioFile> selectedFiles;

  @override
  ConsumerState<_AlbumArtTab> createState() => _AlbumArtTabState();
}

class _AlbumArtTabState extends ConsumerState<_AlbumArtTab> {
  BatchProgress? _batchProgress;
  bool _showCompletionSummary = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final artState = detectArtState(widget.selectedFiles);
    final displayArt = _getDisplayArt(artState);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            HardwareKeyboard.instance.isControlPressed) {
          _handleClipboardPaste();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DropZoneWrapper(
        onImageDropped: _handleImageDropped,
        onError: (message) => _showError(message),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildArtDisplay(colorScheme, artState, displayArt),
                  const SizedBox(height: 8),
                  if (displayArt != null)
                    _buildArtInfo(colorScheme, displayArt),
                  if (artState == ArtDisplayState.mixed)
                    Text(
                      'Mixed album art (${widget.selectedFiles.length} files)',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildButtons(colorScheme, displayArt),
                ],
              ),
            ),
            if (_batchProgress != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: BatchProgressOverlay(
                  progress: _batchProgress!,
                  onDismiss: () => setState(() {
                    _batchProgress = null;
                    _showCompletionSummary = false;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtDisplay(
    ColorScheme colorScheme,
    ArtDisplayState artState,
    AlbumArtData? displayArt,
  ) {
    return GestureDetector(
      onTap: displayArt != null
          ? () => ImagePreviewModal.show(context, displayArt)
          : null,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(4),
        ),
        child: displayArt != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.memory(displayArt.bytes, fit: BoxFit.cover),
              )
            : artState == ArtDisplayState.mixed
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.collections_outlined,
                    size: 40,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mixed',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              )
            : Icon(
                Icons.image_outlined,
                size: 48,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
      ),
    );
  }

  Widget _buildArtInfo(ColorScheme colorScheme, AlbumArtData art) {
    final dimensions = getImageDimensions(art.bytes);
    final parts = <String>[
      art.mimeType,
      '${(art.bytes.length / 1024).toStringAsFixed(0)} KB',
    ];
    if (dimensions != null) {
      parts.add('${dimensions.width} × ${dimensions.height}');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        parts.join(' • '),
        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildButtons(ColorScheme colorScheme, AlbumArtData? displayArt) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CompactButton(label: 'Add', icon: Icons.add, onPressed: _handleAdd),
        const SizedBox(width: 6),
        _CompactOutlineButton(
          label: 'Export',
          icon: Icons.save_alt,
          onPressed: displayArt != null
              ? () => _handleExport(displayArt)
              : null,
        ),
        const SizedBox(width: 6),
        _CompactOutlineButton(
          label: 'Remove',
          icon: Icons.delete_outline,
          onPressed:
              (displayArt != null ||
                  widget.selectedFiles.any((f) => f.albumArt != null))
              ? _handleRemove
              : null,
        ),
      ],
    );
  }

  AlbumArtData? _getDisplayArt(ArtDisplayState artState) {
    switch (artState) {
      case ArtDisplayState.single:
        return widget.selectedFiles.first.albumArt;
      case ArtDisplayState.shared:
        return widget.selectedFiles.first.albumArt;
      case ArtDisplayState.mixed:
      case ArtDisplayState.none:
        return null;
    }
  }

  Future<void> _handleAdd() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: 'Select Album Art',
    );
    if (result == null || result.files.first.path == null) return;

    final file = File(result.files.first.path!);
    final bytes = await file.readAsBytes();
    final mimeType = detectMimeType(bytes) ?? 'image/jpeg';

    if (!isValidImageMimeType(mimeType)) {
      _showError('Only image files (JPEG, PNG, BMP, GIF, WebP) are supported.');
      return;
    }

    if (exceedsSizeThreshold(bytes.length)) {
      final proceed = await _showSizeWarning(bytes.length);
      if (!proceed) return;
    }

    await _applyAlbumArt(bytes, mimeType);
  }

  Future<void> _handleRemove() async {
    if (widget.selectedFiles.length > 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Album Art'),
          content: Text(
            'Remove album art from ${widget.selectedFiles.length} files?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final manager = ref.read(albumArtManagerProvider);
    await for (final progress in manager.removeAlbumArt(
      files: widget.selectedFiles,
    )) {
      if (mounted) {
        setState(() => _batchProgress = progress);
      }
    }

    if (mounted) {
      setState(() => _showCompletionSummary = true);
      _autoDismissProgress();
    }
  }

  Future<void> _handleExport(AlbumArtData art) async {
    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Export Album Art',
      fileName: 'cover.jpg',
    );
    if (outputPath != null) {
      await File(outputPath).writeAsBytes(art.bytes);
    }
  }

  void _handleImageDropped(Uint8List bytes, String mimeType) async {
    if (exceedsSizeThreshold(bytes.length)) {
      final proceed = await _showSizeWarning(bytes.length);
      if (!proceed) return;
    }
    await _applyAlbumArt(bytes, mimeType);
  }

  Future<void> _handleClipboardPaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

    if (clipboardData?.text != null) {
      final path = clipboardData!.text!.trim();
      final file = File(path);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        final mimeType = detectMimeType(bytes);
        if (mimeType != null && isValidImageMimeType(mimeType)) {
          if (exceedsSizeThreshold(bytes.length)) {
            final proceed = await _showSizeWarning(bytes.length);
            if (!proceed) return;
          }
          await _applyAlbumArt(bytes, mimeType);
          return;
        }
      }
    }

    _showError('No image found on clipboard');
  }

  Future<void> _applyAlbumArt(Uint8List bytes, String mimeType) async {
    final manager = ref.read(albumArtManagerProvider);
    await for (final progress in manager.addAlbumArt(
      files: widget.selectedFiles,
      imageBytes: bytes,
      mimeType: mimeType,
    )) {
      if (mounted) {
        setState(() => _batchProgress = progress);
      }
    }

    if (mounted) {
      setState(() => _showCompletionSummary = true);
      _autoDismissProgress();
    }
  }

  void _autoDismissProgress() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showCompletionSummary) {
        setState(() {
          _batchProgress = null;
          _showCompletionSummary = false;
        });
      }
    });
  }

  Future<bool> _showSizeWarning(int sizeBytes) async {
    final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Large Image'),
            content: Text(
              'This image is $sizeMB MB. Large embedded art increases '
              'file size. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}

// ---------------------------------------------------------------------------
// File Info tab
// ---------------------------------------------------------------------------

class _FileInfoTab extends StatelessWidget {
  const _FileInfoTab({required this.selectedFiles});

  final List<AudioFile> selectedFiles;

  @override
  Widget build(BuildContext context) {
    if (selectedFiles.isEmpty) {
      return const Center(child: Text('No file selected'));
    }

    if (selectedFiles.length > 1) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${selectedFiles.length} files selected',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Total size',
              value: _formatBytes(
                selectedFiles.fold(0, (sum, f) => sum + f.fileSize),
              ),
            ),
            _InfoRow(
              label: 'Formats',
              value: selectedFiles.map((f) => f.extension).toSet().join(', '),
            ),
          ],
        ),
      );
    }

    final file = selectedFiles.first;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Filename', value: file.filename),
          _InfoRow(label: 'Path', value: file.path),
          _InfoRow(label: 'Format', value: file.extension.toUpperCase()),
          _InfoRow(
            label: 'Tag Format',
            value: _tagFormatDisplayName(file.tagFormat),
          ),
          _InfoRow(label: 'Size', value: _formatBytes(file.fileSize)),
          if (file.duration != null)
            _InfoRow(label: 'Duration', value: _formatDuration(file.duration!)),
          if (file.bitrate != null)
            _InfoRow(label: 'Bitrate', value: '${file.bitrate} kbps'),
          if (file.sampleRate != null)
            _InfoRow(label: 'Sample Rate', value: '${file.sampleRate} Hz'),
          if (file.channels != null)
            _InfoRow(
              label: 'Channels',
              value: file.channels == 1 ? 'Mono' : 'Stereo',
            ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _tagFormatDisplayName(TagFormat? format) {
    switch (format) {
      case TagFormat.id3v1:
        return 'ID3 v1';
      case TagFormat.id3v2_3:
        return 'ID3 v2.3';
      case TagFormat.id3v2_4:
        return 'ID3 v2.4';
      case TagFormat.vorbisComment:
        return 'Vorbis Comment';
      case TagFormat.apeTag:
        return 'APE v2';
      case TagFormat.asf:
        return 'ASF (WMA)';
      case TagFormat.mp4Atoms:
        return 'MP4 / iTunes';
      case TagFormat.unknown:
        return 'Tagged (format unknown)';
      case null:
        return 'None detected';
    }
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

/// A compact outlined button for the album art actions.
class _CompactOutlineButton extends StatelessWidget {
  const _CompactOutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: isEnabled
              ? colorScheme.outline
              : colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: isEnabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isEnabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
