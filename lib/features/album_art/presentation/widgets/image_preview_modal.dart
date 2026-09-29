import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/models/audio_file.dart';

/// Full-screen modal dialog displaying album art at full resolution.
///
/// Supports zoom/pan via [InteractiveViewer]. Closes on tap outside
/// the image area or on Escape key press.
class ImagePreviewModal extends StatelessWidget {
  /// Creates an [ImagePreviewModal] for the given [albumArt].
  const ImagePreviewModal({super.key, required this.albumArt});

  /// The album art data to display.
  final AlbumArtData albumArt;

  /// Shows the preview modal as a dialog.
  static Future<void> show(BuildContext context, AlbumArtData albumArt) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => ImagePreviewModal(albumArt: albumArt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when tapping the image
                  child: InteractiveViewer(
                    maxScale: 5.0,
                    child: Image.memory(albumArt.bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${albumArt.mimeType} • ${(albumArt.bytes.length / 1024).toStringAsFixed(0)} KB',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
