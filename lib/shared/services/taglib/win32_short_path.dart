import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Provides Windows short path (8.3 format) conversion for file paths
/// containing characters that can't be represented in the system's ANSI
/// code page (e.g., emoji, CJK characters).
///
/// This is needed because TagLib's C API `taglib_file_new` uses `fopen`
/// internally, which on Windows can only handle paths representable in
/// the active code page. The short path is always ASCII-safe.
class Win32ShortPath {
  Win32ShortPath._();

  static final _kernel32 = DynamicLibrary.open('kernel32.dll');

  static final _getShortPathNameW = _kernel32.lookupFunction<
      Uint32 Function(Pointer<Utf16> lpszLongPath, Pointer<Utf16> lpszShortPath,
          Uint32 cchBuffer),
      int Function(Pointer<Utf16> lpszLongPath, Pointer<Utf16> lpszShortPath,
          int cchBuffer)>('GetShortPathNameW');

  /// Returns the Windows 8.3 short path for [longPath], or `null` if
  /// the conversion fails (e.g., short names are disabled on the volume).
  ///
  /// Only call this on Windows. On other platforms, returns `null`.
  static String? getShortPath(String longPath) {
    if (!Platform.isWindows) return null;

    final lpLongPath = longPath.toNativeUtf16();
    try {
      // First call to get required buffer size.
      final requiredSize = _getShortPathNameW(lpLongPath, nullptr, 0);
      if (requiredSize == 0) return null;

      final lpShortPath = calloc<Uint16>(requiredSize);
      try {
        final result = _getShortPathNameW(
          lpLongPath,
          lpShortPath.cast<Utf16>(),
          requiredSize,
        );
        if (result == 0 || result > requiredSize) return null;

        return lpShortPath.cast<Utf16>().toDartString();
      } finally {
        calloc.free(lpShortPath);
      }
    } finally {
      malloc.free(lpLongPath);
    }
  }

  /// Returns `true` if [path] contains characters outside the ASCII
  /// printable range (0x20–0x7E), which may cause issues with ANSI
  /// file APIs on Windows.
  static bool hasNonAsciiChars(String path) {
    for (var i = 0; i < path.length; i++) {
      final code = path.codeUnitAt(i);
      if (code > 0x7E) return true;
    }
    return false;
  }
}
