import 'package:open_tag_editor/features/settings/data/models/id3v2_version.dart';
import 'package:open_tag_editor/features/settings/data/models/tag_encoding.dart';

/// Options controlling how tags are written to audio files.
///
/// This value object is passed to `TagLibWriterService` at write-time to
/// determine the ID3v2 version, text encoding, and whether to also write
/// legacy ID3v1 tags.
class TagWriteOptions {
  const TagWriteOptions({
    this.id3v2Version = Id3v2Version.v24,
    this.writeId3v1 = false,
    this.encoding = TagEncoding.utf8,
  });

  /// The ID3v2 sub-version to write (2.3 or 2.4).
  final Id3v2Version id3v2Version;

  /// Whether to also write legacy ID3v1 tags alongside ID3v2.
  final bool writeId3v1;

  /// The text encoding for ID3v2 frames.
  final TagEncoding encoding;
}
