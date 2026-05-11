import 'dart:io';

import 'package:path/path.dart' as p;

import '../tag_reader_service.dart';

/// Manages atomic file write operations using a temp-file-then-rename pattern.
///
/// This ensures the original file is never corrupted by a failed write.
/// The sequence is:
/// 1. Copy original to a temp file in the same directory
/// 2. Perform the write operation on the temp file
/// 3. Rename the temp file over the original (atomic on same filesystem)
class AtomicWriteManager {
  /// Performs an atomic write operation on [originalPath].
  ///
  /// 1. Copies the original file to a temp file in the same directory
  /// 2. Calls [writeOperation] with the temp file path
  /// 3. On success: renames temp file over original (atomic filesystem op)
  /// 4. On write failure: deletes temp file, original unchanged
  /// 5. On rename failure: retains both files, throws [TagWriteException]
  Future<void> writeAtomic(
    String originalPath,
    Future<void> Function(String tempPath) writeOperation,
  ) async {
    final originalFile = File(originalPath);
    final directory = p.dirname(originalPath);
    final fileName = p.basename(originalPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempPath = p.join(directory, '$fileName.tmp_$timestamp');

    // Step 1: Copy original to temp file
    final tempFile = await originalFile.copy(tempPath);

    // Step 2: Perform the write operation on the temp file
    try {
      await writeOperation(tempPath);
    } catch (e) {
      // On write failure: delete temp file, rethrow
      try {
        await tempFile.delete();
      } catch (_) {
        // Best-effort cleanup; ignore deletion errors
      }
      rethrow;
    }

    // Step 3: Rename temp file over original (atomic on same filesystem)
    try {
      await File(tempPath).rename(originalPath);
    } catch (e) {
      // On rename failure: retain both files, throw with details
      throw TagWriteException(
        'Atomic rename failed. Temp file retained at: $tempPath. '
        'Original unchanged at: $originalPath. '
        'Rename error: $e',
        originalPath,
      );
    }
  }
}
