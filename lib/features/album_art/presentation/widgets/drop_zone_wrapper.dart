import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../data/image_validator.dart';

/// Wraps child content with drag-and-drop support for image files.
///
/// Shows a visual border highlight when a valid image is dragged over.
/// Validates dropped files and calls [onImageDropped] with the image bytes
/// and detected MIME type.
class DropZoneWrapper extends StatefulWidget {
  const DropZoneWrapper({
    super.key,
    required this.child,
    required this.onImageDropped,
    this.onError,
  });

  /// The child widget to wrap with drop support.
  final Widget child;

  /// Called when a valid image file is dropped.
  final void Function(Uint8List bytes, String mimeType) onImageDropped;

  /// Called when an invalid file is dropped (non-image).
  final void Function(String message)? onError;

  @override
  State<DropZoneWrapper> createState() => _DropZoneWrapperState();
}

class _DropZoneWrapperState extends State<DropZoneWrapper> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _handleDrop(details);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: _isDragging
              ? Border.all(color: colorScheme.primary, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.child,
      ),
    );
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return;

    final droppedFile = details.files.first;
    final file = File(droppedFile.path);

    if (!file.existsSync()) {
      widget.onError?.call('File does not exist.');
      return;
    }

    final bytes = await file.readAsBytes();
    final mimeType = detectMimeType(bytes);

    if (mimeType == null || !isValidImageMimeType(mimeType)) {
      widget.onError?.call(
        'Only image files (JPEG, PNG, BMP, GIF, WebP) are supported.',
      );
      return;
    }

    widget.onImageDropped(bytes, mimeType);
  }
}
