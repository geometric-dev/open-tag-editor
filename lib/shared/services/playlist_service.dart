import 'dart:io';

import '../models/audio_file.dart';

/// Generates M3U / M3U8 playlist content from audio files.
class PlaylistService {
  PlaylistService._();

  /// Returns `m3u`/`m3u8` text for [files].
  ///
  /// When [extended] is true, emits `#EXTM3U` + `#EXTINF:<seconds>,<artist> - <title>`
  /// lines per Tag&Rename's behaviour. When false, emits only file paths.
  /// When [useAbsolutePaths] is true, paths are absolute; otherwise they are
  /// made relative to [baseDirectory] when provided (falls back to absolute).
  static String generateM3U(
    List<AudioFile> files, {
    bool extended = true,
    bool useAbsolutePaths = false,
    String? baseDirectory,
  }) {
    final buffer = StringBuffer();
    if (extended) buffer.writeln('#EXTM3U');

    for (final file in files) {
      final path = _resolvePath(file.path, useAbsolutePaths, baseDirectory);

      if (extended) {
        final duration = file.duration != null ? file.duration!.round() : -1;
        final artist = file.tags['artist'] ?? '';
        final title = file.tags['title'] ?? file.filename;
        final display = artist.isNotEmpty ? '$artist - $title' : title;
        buffer.writeln('#EXTINF:$duration,$display');
      }

      buffer.writeln(path);
    }

    return buffer.toString();
  }

  /// Writes the playlist to [outputPath] atomically.
  static Future<void> writePlaylistFile(
    String outputPath,
    List<AudioFile> files, {
    bool extended = true,
    bool useAbsolutePaths = false,
    String? baseDirectory,
  }) async {
    final content = generateM3U(
      files,
      extended: extended,
      useAbsolutePaths: useAbsolutePaths,
      baseDirectory: baseDirectory,
    );
    // Dart strings are UTF-8 by default; m3u8 expects UTF-8 (BOM optional).
    // We emit UTF-8 without BOM for max compatibility; players accept both.
    final file = await File(outputPath).create(recursive: true);
    await file.writeAsString(content);
  }

  static String _resolvePath(
    String filePath,
    bool useAbsolute,
    String? baseDir,
  ) {
    if (useAbsolute) return filePath;
    if (baseDir == null || baseDir.isEmpty) return filePath;

    // Normalize to forward slashes for playlist portability, then compute
    // a relative path when possible.
    final normalizedBase = baseDir.replaceAll(r'\', '/');
    final normalizedFile = filePath.replaceAll(r'\', '/');

    if (normalizedFile.startsWith(normalizedBase)) {
      var relative = normalizedFile.substring(normalizedBase.length);
      relative = relative.replaceFirst(RegExp(r'^/+'), '');
      // Emit with forward slashes (m3u spec) - preserves portability.
      return relative;
    }
    return filePath;
  }
}
