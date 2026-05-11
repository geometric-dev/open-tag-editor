import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/supported_formats.dart';

/// Utility functions for file operations.
class FileUtils {
  FileUtils._();

  /// Returns the file extension in lowercase (including the dot).
  static String getExtension(String path) {
    return p.extension(path).toLowerCase();
  }

  /// Returns true if the file at [path] is a supported audio file.
  static bool isAudioFile(String path) {
    return SupportedFormats.isSupported(getExtension(path));
  }

  /// Recursively lists all supported audio files in a directory.
  static Future<List<File>> listAudioFiles(
    String directoryPath, {
    bool recursive = true,
  }) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    final files = <File>[];
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File && isAudioFile(entity.path)) {
        files.add(entity);
      }
    }
    return files;
  }

  /// Counts supported audio files in a directory without loading them.
  ///
  /// Useful for threshold guard checks before committing to a full load.
  /// Stops counting at [limit] + 1 to avoid scanning the entire tree
  /// when we only need to know if the count exceeds the threshold.
  static Future<int> countAudioFiles(
    String directoryPath, {
    bool recursive = true,
    int limit = 500,
  }) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return 0;

    var count = 0;
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File && isAudioFile(entity.path)) {
        count++;
        if (count > limit) return count; // Early exit
      }
    }
    return count;
  }

  /// Generates a safe filename by removing invalid characters.
  static String sanitizeFilename(String filename) {
    // Characters not allowed in filenames on Windows
    const invalidChars = r'<>:"/\|?*';
    var sanitized = filename;
    for (final char in invalidChars.split('')) {
      sanitized = sanitized.replaceAll(char, '_');
    }
    // Remove leading/trailing dots and spaces
    sanitized = sanitized.trim().replaceAll(RegExp(r'^\.+|\.+$'), '');
    return sanitized.isEmpty ? 'unnamed' : sanitized;
  }
}
