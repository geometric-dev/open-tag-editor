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
      _cachedLibrary = _loadWindows();
    } else if (Platform.isMacOS) {
      _cachedLibrary = _loadMacOS();
    } else if (Platform.isLinux) {
      _cachedLibrary = _loadLinux();
    } else {
      throw NativeLibraryException(
        'Unsupported platform: ${Platform.operatingSystem}',
        Platform.operatingSystem,
        '',
      );
    }

    return _cachedLibrary!;
  }

  static DynamicLibrary _loadWindows() {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    final libraryPath = '$execDir\\taglib_c.dll';

    try {
      return DynamicLibrary.open(libraryPath);
    } catch (e) {
      throw NativeLibraryException(
        'Failed to load TagLib native library on Windows: $e',
        'windows',
        libraryPath,
      );
    }
  }

  static DynamicLibrary _loadMacOS() {
    final execPath = File(Platform.resolvedExecutable).parent.path;
    // The executable is at <app_bundle>/Contents/MacOS/app_name,
    // so Frameworks is at <app_bundle>/Contents/Frameworks/.
    final frameworksDir =
        '${Directory(execPath).parent.path}/Frameworks';
    final libraryPath = '$frameworksDir/libtaglib_c.dylib';

    try {
      return DynamicLibrary.open(libraryPath);
    } catch (e) {
      throw NativeLibraryException(
        'Failed to load TagLib native library on macOS: $e',
        'macos',
        libraryPath,
      );
    }
  }

  static DynamicLibrary _loadLinux() {
    final execDir = File(Platform.resolvedExecutable).parent.path;
    final libraryPath = '$execDir/libtaglib_c.so';

    // Try loading from adjacent to the executable first.
    try {
      return DynamicLibrary.open(libraryPath);
    } catch (_) {
      // Fall back to system library paths.
    }

    const systemName = 'libtaglib_c.so';
    try {
      return DynamicLibrary.open(systemName);
    } catch (e) {
      throw NativeLibraryException(
        'Failed to load TagLib native library on Linux: $e',
        'linux',
        libraryPath,
      );
    }
  }
}
