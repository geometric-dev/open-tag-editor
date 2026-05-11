import '../../../../shared/models/audio_file.dart';

/// A validated plan for a single file rename.
class RenamePlan {
  const RenamePlan({
    required this.sourcePath,
    required this.targetPath,
    required this.audioFile,
  });

  /// Current path of the file.
  final String sourcePath;

  /// Target path after rename.
  final String targetPath;

  /// The audio file being renamed.
  final AudioFile audioFile;
}
