import 'package:open_tag_editor/features/settings/data/models/id3v2_version.dart';
import 'package:open_tag_editor/features/settings/data/models/tag_encoding.dart';

/// Persisted tag-writing settings.
class TagWritingSettings {
  const TagWritingSettings({
    this.id3v2Version = Id3v2Version.v24,
    this.writeId3v1 = false,
    this.encoding = TagEncoding.utf8,
  });

  /// The ID3v2 sub-version to write (2.3 or 2.4).
  final Id3v2Version id3v2Version;

  /// Whether to also write legacy ID3v1 tags.
  final bool writeId3v1;

  /// The text encoding for ID3v2 frames.
  final TagEncoding encoding;

  /// Creates a copy with updated fields.
  TagWritingSettings copyWith({
    Id3v2Version? id3v2Version,
    bool? writeId3v1,
    TagEncoding? encoding,
  }) {
    return TagWritingSettings(
      id3v2Version: id3v2Version ?? this.id3v2Version,
      writeId3v1: writeId3v1 ?? this.writeId3v1,
      encoding: encoding ?? this.encoding,
    );
  }
}
