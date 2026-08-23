import 'dart:convert';
import 'dart:io';

import 'models/acoustid_models.dart';

/// Generates Chromaprint audio fingerprints by invoking the `fpcalc` binary.
///
/// Requires `fpcalc` (from Chromaprint) to be installed and accessible
/// at the configured path.
class FingerprintGenerator {
  /// Creates a [FingerprintGenerator] with the path to the `fpcalc` binary.
  FingerprintGenerator({required this.fpcalcPath});

  /// Path to the `fpcalc` executable.
  final String fpcalcPath;

  /// Generates a fingerprint for the given audio file.
  ///
  /// Throws [FingerprintException] if:
  /// - The `fpcalc` binary is not found
  /// - The process times out (>10 seconds)
  /// - The process exits with a non-zero code
  Future<FingerprintResult> generate(String filePath) async {
    if (!File(fpcalcPath).existsSync() && !await _isInPath()) {
      throw FingerprintException(
        'fpcalc binary not found at: $fpcalcPath. '
        'Please configure the correct path in Settings.',
        filePath,
      );
    }

    final effectivePath = File(fpcalcPath).existsSync() ? fpcalcPath : 'fpcalc';

    try {
      final result = await Process.run(
        effectivePath,
        ['-json', filePath],
        stdoutEncoding: systemEncoding,
        stderrEncoding: systemEncoding,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw FingerprintException(
            'fpcalc timed out after 10 seconds',
            filePath,
          );
        },
      );

      if (result.exitCode != 0) {
        throw FingerprintException(
          'fpcalc exited with code ${result.exitCode}: ${result.stderr}',
          filePath,
        );
      }

      return _parseOutput(result.stdout as String, filePath);
    } on FingerprintException {
      rethrow;
    } catch (e) {
      throw FingerprintException('Failed to run fpcalc: $e', filePath);
    }
  }

  /// Generates fingerprints for multiple files sequentially.
  ///
  /// Reports progress via [onProgress] callback.
  /// Continues processing on individual file failures.
  Future<List<FingerprintResult>> generateBatch(
    List<String> filePaths, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <FingerprintResult>[];

    for (var i = 0; i < filePaths.length; i++) {
      try {
        final result = await generate(filePaths[i]);
        results.add(result);
      } on FingerprintException {
        // Skip failed files, continue with remaining
      }
      onProgress?.call(i + 1, filePaths.length);
    }

    return results;
  }

  /// Parses fpcalc JSON output into a [FingerprintResult].
  FingerprintResult _parseOutput(String output, String filePath) {
    try {
      final json = jsonDecode(output) as Map<String, dynamic>;
      final duration = (json['duration'] as num?)?.toDouble();
      final fingerprint = json['fingerprint'] as String?;

      if (duration == null || fingerprint == null) {
        throw FingerprintException(
          'Missing duration or fingerprint in fpcalc output',
          filePath,
        );
      }

      return FingerprintResult(
        filePath: filePath,
        fingerprint: fingerprint,
        durationSeconds: duration.round(),
      );
    } on FormatException catch (e) {
      throw FingerprintException(
        'Failed to parse fpcalc JSON output: $e',
        filePath,
      );
    }
  }

  /// Checks if fpcalc is available in the system PATH.
  Future<bool> _isInPath() async {
    try {
      final result = await Process.run('fpcalc', ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
