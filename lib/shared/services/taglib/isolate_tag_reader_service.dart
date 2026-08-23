import 'dart:async';
import 'dart:isolate';

import '../../models/audio_file.dart';
import '../tag_reader_service.dart';
import 'isolate_tag_io.dart';

/// A [TagReaderService] that keeps the UI isolate responsive.
///
/// - Single-file reads run directly (fast, and typically triggered by
///   user-visible single operations).
/// - Batch reads (folder loads) run inside a background isolate via
///   [Isolate.run]. The worker reconstructs its own native bindings;
///   per-file failures are captured in [AudioFile.readError] exactly as
///   the underlying service does.
class IsolateTagReaderService implements TagReaderService {
  TagReaderService? _directDelegate;

  /// Lazily-created same-isolate instance for single-file reads.
  TagReaderService get _delegate =>
      _directDelegate ??= createPlatformTagReaderService();

  @override
  Future<AudioFile> readTags(String path) => _delegate.readTags(path);

  @override
  Future<List<AudioFile>> readTagsBatch(List<String> paths) async {
    if (paths.isEmpty) return const [];

    // Only sendable data crosses the boundary: the path list in,
    // immutable AudioFile objects out.
    final files = await Isolate.run(() {
      final service = createPlatformTagReaderService();
      return service.readTagsBatch(paths);
    });
    return List.unmodifiable(files);
  }
}
