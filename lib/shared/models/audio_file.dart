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
    this.albumArt,
    this.duration,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.tagFormat,
    this.isModified = false,
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

  /// Creates a copy with updated fields.
  ///
  /// Set [clearAlbumArt] to true to explicitly set albumArt to null.
  AudioFile copyWith({
    String? path,
    String? filename,
    String? extension,
    int? fileSize,
    Map<String, String>? tags,
    AlbumArtData? albumArt,
    bool clearAlbumArt = false,
    double? duration,
    int? bitrate,
    int? sampleRate,
    int? channels,
    TagFormat? tagFormat,
    bool? isModified,
  }) {
    return AudioFile(
      path: path ?? this.path,
      filename: filename ?? this.filename,
      extension: extension ?? this.extension,
      fileSize: fileSize ?? this.fileSize,
      tags: tags ?? this.tags,
      albumArt: clearAlbumArt ? null : (albumArt ?? this.albumArt),
      duration: duration ?? this.duration,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      tagFormat: tagFormat ?? this.tagFormat,
      isModified: isModified ?? this.isModified,
    );
  }

  @override
  List<Object?> get props => [path, isModified];
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
