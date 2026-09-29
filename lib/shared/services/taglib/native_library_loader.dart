import 'dart:ffi';
import 'dart:io';

import 'taglib_types.dart';

/// Loads the platform-specific TagLib shared library via dart:ffi.
///
/// Handles platform detection and resolves the correct library path
/// for Windows, macOS, and Linux.
class NativeLibraryLoader {
  NativeLibraryLoader._();

  static DynamicLibrary? _cachedLibrary;
  static bool? _cachedAvailability;

  /// Returns `true` if the native TagLib library can be loaded on the
  /// current platform.
  ///
  /// The result is cached after the first call to avoid repeated load
  /// attempts.
  static bool get isAvailable {
    if (_cachedAvailability != null) {
      return _cachedAvailability!;
    }
    try {
      load();
      _cachedAvailability = true;
    } on NativeLibraryException {
      _cachedAvailability = false;
    }
    return _cachedAvailability!;
  }

  /// Loads and returns the platform-specific TagLib shared library.
  ///
  /// On success the [DynamicLibrary] is cached so subsequent calls return
  /// the same instance without reloading.
  ///
  /// Throws [NativeLibraryException] if the library cannot be found or
  /// loaded on the current platform.
  static DynamicLibrary load() {
    if (_cachedLibrary != null) {
      return _cachedLibrary!;
    }

    if (Platform.isWindows) {
      _cachedLibrary = _loadWithCandidates(_windowsCandidates());
    } else if (Platform.isMacOS) {
      _cachedLibrary = _loadWithCandidates(_macOSCandidates());
    } else if (Platform.isLinux) {
      _cachedLibrary = _loadWithCandidates(_linuxCandidates());
    } else {
      throw NativeLibraryException(
        'Unsupported platform: ${Platform.operatingSystem}',
        Platform.operatingSystem,
        '',
      );
    }

    return _cachedLibrary!;
  }

  /// Tries each candidate library name/path in order, returning the first
  /// that loads successfully.
  ///
  /// Names without directory separators are resolved by the OS loader
  /// (e.g. system library paths); absolute paths are tried directly.
  /// Throws [NativeLibraryException] listing every attempted location.
  static DynamicLibrary _loadWithCandidates(List<String> candidates) {
    final errors = <String>[];
    for (final candidate in candidates) {
      try {
        return DynamicLibrary.open(candidate);
      } catch (e) {
        errors.add('$candidate -> $e');
      }
    }
    throw NativeLibraryException(
      'Failed to load TagLib native library. Attempted:\n'
      '${errors.join('\n')}',
      Platform.operatingSystem,
      candidates.first,
    );
  }

  /// Windows search locations, most preferred first.
  ///
  /// The installer places taglib_c.dll next to the executable; older
  /// installs placed it under data\.
  static List<String> _windowsCandidates() {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    return ['$execDir\\taglib_c.dll', '$execDir\\data\\taglib_c.dll'];
  }

  /// macOS search locations, most preferred first.
  ///
  /// The app bundle keeps the dylib in Contents/Frameworks/.
  static List<String> _macOSCandidates() {
    final execPath = File(Platform.resolvedExecutable).parent.path;
    // The executable is at <app_bundle>/Contents/MacOS/app_name,
    // so Frameworks is at <app_bundle>/Contents/Frameworks/.
    final frameworksDir = '${Directory(execPath).parent.path}/Frameworks';
    return ['$frameworksDir/libtaglib_c.dylib', '$execPath/libtaglib_c.dylib'];
  }

  /// Linux search locations, most preferred first.
  ///
  /// Falls back to the bare soname so system-installed TagLib works.
  static List<String> _linuxCandidates() {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    return [
      '$execDir/libtaglib_c.so',
      '$execDir/lib/libtaglib_c.so',
      'libtaglib_c.so',
    ];
  }
}
