import 'dart:io' show Platform;

/// Result of sanitizing a filename.
class SanitizeResult {
  /// Creates a [SanitizeResult].
  const SanitizeResult({
    required this.sanitized,
    this.wasModified = false,
    this.warnings = const [],
  });

  /// The sanitized filename.
  final String sanitized;

  /// Whether the filename was modified during sanitization.
  final bool wasModified;

  /// Any warnings generated during sanitization.
  final List<String> warnings;
}

/// A validation error for a resolved path.
class ValidationError {
  /// Creates a [ValidationError].
  const ValidationError({required this.message, required this.type});

  /// Human-readable description of the error.
  final String message;

  /// The category of validation error.
  final ValidationErrorType type;
}

/// Types of validation errors that can occur.
enum ValidationErrorType {
  /// The full path exceeds the OS maximum length.
  pathTooLong,

  /// The filename contains characters not allowed on this OS.
  invalidCharacters,

  /// The filename matches a reserved name (Windows only).
  reservedName,

  /// The filename is empty or contains only whitespace.
  emptyFilename,
}

/// Sanitizes filenames for the current operating system.
class FilenameSanitizer {
  /// Maximum path length for Windows.
  static const int windowsMaxPath = 260;

  /// Maximum path length for Unix-like systems.
  static const int unixMaxPath = 4096;

  /// Characters invalid on Windows.
  static const String _windowsInvalidChars = r'<>:"/\|?*';

  /// Reserved names on Windows (case-insensitive).
  static const List<String> _windowsReservedNames = [
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  ];

  /// Sanitizes [filename] by removing/replacing invalid characters.
  ///
  /// Returns a [SanitizeResult] containing the sanitized filename,
  /// whether modifications were made, and any warnings.
  SanitizeResult sanitize(String filename) {
    // Step 1: If filename is empty or all whitespace, return unchanged with warning.
    if (filename.isEmpty || filename.trim().isEmpty) {
      return SanitizeResult(
        sanitized: filename,
        warnings: ['Filename is empty or contains only whitespace'],
      );
    }

    var result = filename;
    final warnings = <String>[];

    // Step 2: Replace invalid characters based on OS.
    if (Platform.isWindows) {
      // Replace Windows invalid characters with underscore.
      result = result.replaceAll(
        RegExp('[${RegExp.escape(_windowsInvalidChars)}]'),
        '_',
      );
      // Replace control characters (0x00-0x1F).
      result = result.replaceAll(RegExp(r'[\x00-\x1F]'), '_');
    } else {
      // Unix: replace forward slash and null byte with underscore.
      result = result.replaceAll('/', '_');
      result = result.replaceAll('\x00', '_');
    }

    // Step 4: Remove trailing dots and spaces (Windows restriction).
    result = result.replaceAll(RegExp(r'[. ]+$'), '');

    // Step 5: Check if base name matches a reserved name on Windows.
    if (Platform.isWindows) {
      final dotIndex = result.indexOf('.');
      final baseName = dotIndex == -1 ? result : result.substring(0, dotIndex);

      if (_windowsReservedNames.contains(baseName.toUpperCase())) {
        result = '_$result';
        warnings.add(
          'Filename matched reserved name "$baseName", prepended underscore',
        );
      }
    }

    // Step 6: Determine if modifications were made.
    final wasModified = result != filename;

    return SanitizeResult(
      sanitized: result,
      wasModified: wasModified,
      warnings: warnings,
    );
  }

  /// Validates a complete resolved path against OS constraints.
  ///
  /// Returns a list of [ValidationError]s found. An empty list means
  /// the path is valid.
  List<ValidationError> validate(String fullPath) {
    final errors = <ValidationError>[];

    // Step 1: Check path length against OS max.
    final maxPath = Platform.isWindows ? windowsMaxPath : unixMaxPath;
    if (fullPath.length > maxPath) {
      errors.add(
        ValidationError(
          message: 'Path length ${fullPath.length} exceeds maximum $maxPath',
          type: ValidationErrorType.pathTooLong,
        ),
      );
    }

    // Step 2: Extract filename portion (after last separator).
    final separator = Platform.isWindows ? r'\' : '/';
    final lastSepIndex = fullPath.lastIndexOf(separator);
    final filename = lastSepIndex == -1
        ? fullPath
        : fullPath.substring(lastSepIndex + 1);

    // Step 4: Check if filename is empty or all whitespace.
    if (filename.isEmpty || filename.trim().isEmpty) {
      errors.add(
        const ValidationError(
          message: 'Filename is empty or contains only whitespace',
          type: ValidationErrorType.emptyFilename,
        ),
      );
      return errors;
    }

    // Step 2 (continued): Check for invalid characters.
    if (Platform.isWindows) {
      final invalidPattern = RegExp(
        '[${RegExp.escape(_windowsInvalidChars)}\\x00-\\x1F]',
      );
      if (invalidPattern.hasMatch(filename)) {
        errors.add(
          const ValidationError(
            message: 'Filename contains characters invalid on Windows',
            type: ValidationErrorType.invalidCharacters,
          ),
        );
      }
    } else {
      if (filename.contains('/') || filename.contains('\x00')) {
        errors.add(
          const ValidationError(
            message: 'Filename contains characters invalid on Unix',
            type: ValidationErrorType.invalidCharacters,
          ),
        );
      }
    }

    // Step 3: Check reserved names (Windows only).
    if (Platform.isWindows) {
      final dotIndex = filename.indexOf('.');
      final baseName = dotIndex == -1
          ? filename
          : filename.substring(0, dotIndex);

      if (_windowsReservedNames.contains(baseName.toUpperCase())) {
        errors.add(
          ValidationError(
            message: '"$baseName" is a reserved name on Windows',
            type: ValidationErrorType.reservedName,
          ),
        );
      }
    }

    return errors;
  }
}
