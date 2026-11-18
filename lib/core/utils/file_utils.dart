import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../constants/supported_formats.dart';
import 'cancellation_token.dart';

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
  ///
  /// Optionally reports progress via [onProgress] as files are discovered,
  /// and checks [cancellationToken] to abort early if cancelled.
  static Future<List<File>> listAudioFiles(
    String directoryPath, {
    bool recursive = true,
    void Function(int count)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    final files = <File>[];
    try {
      await for (final entity in dir.list(recursive: recursive).handleError((
        Object error,
      ) {
        // Skip inaccessible files or subdirectories
      })) {
        if (cancellationToken?.isCancelled == true) break;
        if (entity is File && isAudioFile(entity.path)) {
          files.add(entity);
          onProgress?.call(files.length);
        }
      }
    } catch (_) {
      // In case directory access fails
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
    CancellationToken? cancellationToken,
  }) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return 0;

    var count = 0;
    try {
      await for (final entity in dir.list(recursive: recursive).handleError((
        Object error,
      ) {
        // Skip inaccessible files or subdirectories
      })) {
        if (cancellationToken?.isCancelled == true) break;
        if (entity is File && isAudioFile(entity.path)) {
          count++;
          if (count > limit) return count; // Early exit
        }
      }
    } catch (_) {
      // In case directory access fails
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

  /// Checks whether a file is marked as read-only on the filesystem.
  ///
  /// On Windows, checks the [FILE_ATTRIBUTE_READONLY] attribute via
  /// [FileStat.mode] (which maps Windows file attributes to POSIX bits).
  /// On POSIX systems, checks whether the owner write bit is set.
  ///
  /// Unlike opening the file with write access, this check inspects
  /// filesystem metadata without opening a file handle, avoiding false
  /// positives from sharing violations (e.g. files open in Soulseek,
  /// media players, or indexing services).
  static bool isFileReadOnly(File file, [FileStat? stat]) {
    try {
      final s = stat ?? file.statSync();
      if (s.type == FileSystemEntityType.notFound) return false;
      // 0x80 is S_IWUSR (owner write permission).
      // On Windows, Dart clears S_IWUSR/S_IWGRP/S_IWOTH when FILE_ATTRIBUTE_READONLY is set.
      // On POSIX, S_IWUSR indicates owner write permission.
      return (s.mode & 0x80) == 0;
    } catch (_) {
      return false;
    }
  }

  /// Clears the read-only attribute on [file], allowing it to be modified or deleted.
  static bool clearReadOnly(File file) {
    if (!file.existsSync()) return false;
    if (Platform.isWindows) {
      try {
        final kernel32 = DynamicLibrary.open('kernel32.dll');
        final getFileAttributesW = kernel32
            .lookupFunction<
              Uint32 Function(Pointer<Utf16>),
              int Function(Pointer<Utf16>)
            >('GetFileAttributesW');
        final setFileAttributesW = kernel32
            .lookupFunction<
              Int32 Function(Pointer<Utf16>, Uint32),
              int Function(Pointer<Utf16>, int)
            >('SetFileAttributesW');

        final pathPtr = file.path.toNativeUtf16();
        try {
          final attrs = getFileAttributesW(pathPtr);
          if (attrs != 0xFFFFFFFF) {
            const fileAttributeReadOnly = 0x1;
            if ((attrs & fileAttributeReadOnly) != 0) {
              final newAttrs = attrs & ~fileAttributeReadOnly;
              return setFileAttributesW(pathPtr, newAttrs) != 0;
            }
            return true;
          }
        } finally {
          malloc.free(pathPtr);
        }
      } catch (_) {
        // Fall back to attrib command
      }
      try {
        final res = Process.runSync('attrib', ['-r', file.path]);
        return res.exitCode == 0;
      } catch (_) {
        return false;
      }
    } else {
      try {
        final res = Process.runSync('chmod', ['u+w', file.path]);
        return res.exitCode == 0;
      } catch (_) {
        return false;
      }
    }
  }
}
