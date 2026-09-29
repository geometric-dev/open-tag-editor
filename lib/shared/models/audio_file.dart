import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../services/taglib/taglib_types.dart';

/// Represents a loaded audio file with its metadata.
class AudioFile extends Equatable {
  const AudioFile({
    required this.path,
    required this.filename,
    required this.extension,
    required this.fileSize,
    this.tags = const {},
    this.originalTags,
    this.albumArt,
    this.duration,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.tagFormat,
    this.isModified = false,
    this.isReadOnly = false,
    this.readError,
  });

  /// Full path to the file on disk.
  final String path;

  /// Filename without directory.
  final String filename;

  /// File extension (lowercase, with dot).
  final String extension;

  /// File size in bytes.
  final int fileSize;

  /// Tag data as field name -> value map.
  final Map<String, String> tags;

  /// The tags as originally read from disk.
  ///
  /// Used to compute which fields have actually changed so that only
  /// modified fields are written back. When null, all current [tags] are
  /// considered changed (backwards-compatible default for files created
  /// without this field).
  final Map<String, String>? originalTags;

  /// Embedded album art (first image).
  final AlbumArtData? albumArt;

  /// Duration in seconds.
  final double? duration;

  /// Bitrate in kbps.
  final int? bitrate;

  /// Sample rate in Hz.
  final int? sampleRate;

  /// Number of audio channels.
  final int? channels;

  /// The tag format detected in this file (ID3v2.3, Vorbis Comment, etc.).
  final TagFormat? tagFormat;

  /// Whether the tags have been modified since loading.
  final bool isModified;

  /// Whether the file is read-only on the filesystem.
  final bool isReadOnly;

  /// Error message from tag reading, if the file failed to load tags.
  /// When non-null, the file's tags map will be empty but the file
  /// remains in the list for filename-based operations.
  final String? readError;

  /// Creates a copy with updated fields.
  ///
  /// Set [clearAlbumArt] to true to explicitly set albumArt to null.
  /// Set [clearReadError] to true to explicitly set readError to null.
  AudioFile copyWith({
    String? path,
    String? filename,
    String? extension,
    int? fileSize,
    Map<String, String>? tags,
    Map<String, String>? originalTags,
    bool preserveOriginalTags = true,
    AlbumArtData? albumArt,
    bool clearAlbumArt = false,
    double? duration,
    int? bitrate,
    int? sampleRate,
    int? channels,
    TagFormat? tagFormat,
    bool? isModified,
    bool? isReadOnly,
    String? readError,
    bool clearReadError = false,
  }) {
    return AudioFile(
      path: path ?? this.path,
      filename: filename ?? this.filename,
      extension: extension ?? this.extension,
      fileSize: fileSize ?? this.fileSize,
      tags: tags ?? this.tags,
      originalTags:
          originalTags ?? (preserveOriginalTags ? this.originalTags : null),
      albumArt: clearAlbumArt ? null : (albumArt ?? this.albumArt),
      duration: duration ?? this.duration,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      tagFormat: tagFormat ?? this.tagFormat,
      isModified: isModified ?? this.isModified,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      readError: clearReadError ? null : (readError ?? this.readError),
    );
  }

  /// Equality includes the mutable payload (tags and album art), not just
  /// identity/flags, so providers that diff on [AudioFile] instances also
  /// rebuild when tag contents change even if [isModified] was already true.
  @override
  List<Object?> get props => [
    path,
    tags,
    albumArt,
    isModified,
    isReadOnly,
    readError,
  ];

  /// Returns only the tag fields that differ from [originalTags].
  ///
  /// If [originalTags] is null (legacy files), returns all current [tags].
  Map<String, String> get modifiedTags {
    final original = originalTags;
    if (original == null) return tags;

    final changed = <String, String>{};
    for (final entry in tags.entries) {
      if (original[entry.key] != entry.value) {
        changed[entry.key] = entry.value;
      }
    }
    // Fields that were removed (present in original but not in current tags)
    for (final key in original.keys) {
      if (!tags.containsKey(key)) {
        changed[key] = ''; // empty string signals removal
      }
    }
    return changed;
  }
}

/// Holds album art image data.
class AlbumArtData extends Equatable {
  const AlbumArtData({
    required this.bytes,
    required this.mimeType,
    this.description,
    this.type = AlbumArtType.frontCover,
  });

  final Uint8List bytes;
  final String mimeType;
  final String? description;
  final AlbumArtType type;

  @override
  List<Object?> get props => [mimeType, bytes.length, type];
}

/// Types of album art as defined in ID3v2.
enum AlbumArtType {
  other,
  fileIcon,
  otherFileIcon,
  frontCover,
  backCover,
  leafletPage,
  media,
  leadArtist,
  artist,
  conductor,
  band,
  composer,
  lyricist,
  recordingLocation,
  duringRecording,
  duringPerformance,
  movieCapture,
  brightColouredFish,
  illustration,
  bandLogo,
  publisherLogo,
}
