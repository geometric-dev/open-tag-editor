import 'dart:typed_data';

import '../../../shared/models/audio_file.dart';

/// The display state for album art when files are selected.
enum ArtDisplayState {
  /// Single file selected — show its art (or placeholder if none).
  single,

  /// Multiple files selected, all share identical album art bytes.
  shared,

  /// Multiple files selected with different art (or mix of art/no-art).
  mixed,

  /// No files selected, or all selected files have no art.
  none,
}

/// Detects the album art display state for a list of selected files.
///
/// Returns [ArtDisplayState.single] when exactly one file is selected
/// and it has album art.
/// Returns [ArtDisplayState.shared] when all files have identical art bytes.
/// Returns [ArtDisplayState.mixed] when files have different art.
/// Returns [ArtDisplayState.none] when no files are selected or all lack art.
ArtDisplayState detectArtState(List<AudioFile> files) {
  if (files.isEmpty) return ArtDisplayState.none;
  if (files.length == 1) {
    return files.first.albumArt != null
        ? ArtDisplayState.single
        : ArtDisplayState.none;
  }

  // Multiple files — check if all share the same art
  final firstArt = files.first.albumArt;

  // If all files have no art, return none
  if (files.every((f) => f.albumArt == null)) {
    return ArtDisplayState.none;
  }

  // Check if all files have identical art bytes
  final allSame = files.every((f) {
    if (f.albumArt == null && firstArt == null) return true;
    if (f.albumArt == null || firstArt == null) return false;
    return _bytesEqual(f.albumArt!.bytes, firstArt.bytes);
  });

  return allSame ? ArtDisplayState.shared : ArtDisplayState.mixed;
}

/// Compares two byte arrays for equality.
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
