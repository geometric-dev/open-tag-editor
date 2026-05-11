/// A result from the AcoustID fingerprint lookup.
class AcoustIDResult {
  const AcoustIDResult({
    required this.recordingId,
    required this.confidence,
    this.title,
    this.artist,
  });

  /// MusicBrainz recording ID.
  final String recordingId;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Recording title, if available in the AcoustID response.
  final String? title;

  /// Recording artist, if available in the AcoustID response.
  final String? artist;
}

/// Result of generating a Chromaprint fingerprint for an audio file.
class FingerprintResult {
  const FingerprintResult({
    required this.filePath,
    required this.fingerprint,
    required this.durationSeconds,
  });

  /// Path to the audio file that was fingerprinted.
  final String filePath;

  /// The Chromaprint fingerprint string.
  final String fingerprint;

  /// Duration of the audio in seconds.
  final int durationSeconds;
}

/// Exception thrown when fingerprint generation fails.
class FingerprintException implements Exception {
  const FingerprintException(this.message, this.filePath);

  /// Description of the failure.
  final String message;

  /// Path to the file that failed.
  final String filePath;

  @override
  String toString() => 'FingerprintException: $message (file: $filePath)';
}
