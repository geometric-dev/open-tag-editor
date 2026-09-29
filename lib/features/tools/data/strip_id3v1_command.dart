import 'dart:io';

import '../../../../core/constants/supported_formats.dart';
import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../shared/models/audio_file.dart';
import '../../../../shared/services/id3v1_codec.dart';

/// An ID3v1 block only ever exists on MP3 files.
bool _isMp3(AudioFile file) =>
    file.extension.toLowerCase() == SupportedFormats.mp3;

/// Outcome of a batch ID3v1 removal.
class StripId3v1Result {
  const StripId3v1Result({
    required this.stripped,
    required this.skipped,
    required this.errors,
  });

  /// Files whose ID3v1 block was removed.
  final List<String> stripped;

  /// Files skipped: not an MP3, or no ID3v1 block present.
  final List<String> skipped;

  /// Path -> failure message.
  final Map<String, String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// Undoable removal of the trailing ID3v1 block from MP3 files.
///
/// Unlike [ClearTagsCommand] this writes to disk immediately: an ID3v1 block
/// is a standalone 128-byte trailer that TagLib's Properties API cannot
/// address, so there is no way to express "remove this tag" as a property
/// write. Undo therefore re-materialises the block from the values captured
/// before stripping.
class StripId3v1Command implements UndoableCommand {
  StripId3v1Command({
    required this.files,
    required this.previousTags,
    required this.description,
  });

  /// The files this command was built for, in the order processed.
  final List<AudioFile> files;

  /// Path -> ID3v1 values read before the block was removed. Only entries
  /// for files that actually had a block are present, so undo never
  /// invents a tag that did not exist.
  final Map<String, Map<String, String>> previousTags;

  @override
  final String description;

  @override
  void execute() {
    stripId3v1From(files);
  }

  @override
  void undo() {
    for (final entry in previousTags.entries) {
      try {
        Id3v1Codec.writeToFile(entry.key, entry.value);
      } on FileSystemException {
        // Undo is best-effort: a file that vanished or became unwritable
        // since the strip cannot be restored, and there is nothing useful
        // for the caller to do about it here.
        continue;
      }
    }
  }

  /// Removes the ID3v1 block from every MP3 in [files] that has one.
  ///
  /// Returns per-file outcomes so the caller can report the
  /// modified / skipped / errors summary the batch UI promises.
  static StripId3v1Result stripId3v1From(Iterable<AudioFile> files) {
    final stripped = <String>[];
    final skipped = <String>[];
    final errors = <String, String>{};

    for (final file in files) {
      if (!_isMp3(file)) {
        skipped.add(file.path);
        continue;
      }
      try {
        if (Id3v1Codec.stripFromFile(file.path)) {
          stripped.add(file.path);
        } else {
          skipped.add(file.path);
        }
      } on FileSystemException catch (e) {
        errors[file.path] = e.message;
      }
    }

    return StripId3v1Result(
      stripped: stripped,
      skipped: skipped,
      errors: errors,
    );
  }

  /// Builds a command that removes the ID3v1 block from [files], capturing
  /// the current ID3v1 values first so [undo] can put them back.
  ///
  /// Only files that currently have a readable ID3v1 block are included, so
  /// the resulting plan matches the files that will actually change.
  static StripId3v1Command? planFor(Iterable<AudioFile> files) {
    final candidates = <AudioFile>[];
    final previous = <String, Map<String, String>>{};

    for (final file in files) {
      if (!_isMp3(file)) continue;
      final existing = _readId3v1(file.path);
      if (existing == null) continue;
      candidates.add(file);
      previous[file.path] = existing;
    }

    if (candidates.isEmpty) return null;

    return StripId3v1Command(
      files: candidates,
      previousTags: previous,
      description: 'Remove ID3v1 tag (${candidates.length} file(s))',
    );
  }

  static Map<String, String>? _readId3v1(String path) {
    try {
      return Id3v1Codec.readFromFile(path);
    } on FileSystemException {
      return null;
    }
  }
}
