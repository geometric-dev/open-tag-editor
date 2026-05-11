import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../../models/audio_file.dart';
import '../tag_reader_service.dart';
import 'tag_property_mapper.dart';
import 'taglib_bindings.g.dart';
import 'taglib_types.dart';

/// Reads audio file tags using TagLib via FFI bindings.
///
/// This implementation uses the TagLib Properties API to read all tag fields
/// in a format-agnostic way, and the Complex Properties API for album art.
class TagLibReaderService implements TagReaderService {
  /// Creates a [TagLibReaderService] with the given [bindings].
  TagLibReaderService(this._bindings);

  final TagLibBindings _bindings;

  @override
  Future<AudioFile> readTags(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw TagReadException('File does not exist', path);
    }

    final nativePath = path.toNativeUtf8();
    Pointer<TagLib_File> tagFile = nullptr;

    try {
      tagFile = _bindings.taglib_file_new(nativePath);

      if (tagFile == nullptr) {
        throw TagReadException('Failed to open file', path);
      }

      if (_bindings.taglib_file_is_valid(tagFile) == 0) {
        throw TagReadException('File is not a valid audio file', path);
      }

      final tags = _readProperties(tagFile);
      final audioProps = _readAudioProperties(tagFile);
      final albumArt = _readAlbumArt(tagFile);
      final tagFormat = _detectTagFormat(p.extension(path).toLowerCase(), tags);

      final stat = file.statSync();

      return AudioFile(
        path: path,
        filename: p.basename(path),
        extension: p.extension(path).toLowerCase(),
        fileSize: stat.size,
        tags: tags,
        albumArt: albumArt,
        duration: audioProps.duration,
        bitrate: audioProps.bitrate,
        sampleRate: audioProps.sampleRate,
        channels: audioProps.channels,
        tagFormat: tagFormat,
      );
    } finally {
      malloc.free(nativePath);
      if (tagFile != nullptr) {
        _bindings.taglib_file_free(tagFile);
      }
    }
  }

  @override
  Future<List<AudioFile>> readTagsBatch(List<String> paths) async {
    final results = <AudioFile>[];

    for (final path in paths) {
      try {
        final audioFile = await readTags(path);
        results.add(audioFile);
      } catch (_) {
        // On failure, include file with empty tags
        final file = File(path);
        results.add(AudioFile(
          path: path,
          filename: p.basename(path),
          extension: p.extension(path).toLowerCase(),
          fileSize: file.existsSync() ? file.statSync().size : 0,
        ),);
      }
    }

    return results;
  }

  /// Reads all tag properties from the file using the Properties API.
  Map<String, String> _readProperties(Pointer<TagLib_File> tagFile) {
    final tags = <String, String>{};
    final keysPtr = _bindings.taglib_property_keys(tagFile);

    if (keysPtr == nullptr) return tags;

    try {
      final keys = _readStringArray(keysPtr);

      for (final key in keys) {
        final keyNative = key.toNativeUtf8();
        try {
          final valuesPtr = _bindings.taglib_property_get(tagFile, keyNative);
          if (valuesPtr == nullptr) continue;

          try {
            final values = _readStringArray(valuesPtr);
            if (values.isEmpty) continue;

            final value = values.first;
            if (value.isEmpty) continue;

            _mapPropertyToTags(key, value, tags);
          } finally {
            _bindings.taglib_property_free(valuesPtr);
          }
        } finally {
          malloc.free(keyNative);
        }
      }
    } finally {
      _bindings.taglib_property_free(keysPtr);
    }

    return tags;
  }

  /// Maps a TagLib property key/value pair into the app's tag map,
  /// handling track/disc number splitting.
  void _mapPropertyToTags(
    String tagLibKey,
    String value,
    Map<String, String> tags,
  ) {
    final appField = TagPropertyMapper.toAppField(tagLibKey);
    if (appField == null) return;

    // Handle track/disc number fields that may contain "3/12" format
    if (appField == 'trackNumber' || appField == 'discNumber') {
      final (number, total) = TagPropertyMapper.parseTrackNumber(value);
      tags[appField] = number;

      final totalField =
          appField == 'trackNumber' ? 'trackTotal' : 'discTotal';
      if (total != null && !tags.containsKey(totalField)) {
        tags[totalField] = total;
      }
    } else {
      tags[appField] = value;
    }
  }

  /// Reads audio properties (duration, bitrate, sample rate, channels).
  _AudioProperties _readAudioProperties(Pointer<TagLib_File> tagFile) {
    final propsPtr = _bindings.taglib_file_audioproperties(tagFile);

    if (propsPtr == nullptr) {
      return const _AudioProperties();
    }

    final lengthSeconds = _bindings.taglib_audioproperties_length(propsPtr);
    final bitrate = _bindings.taglib_audioproperties_bitrate(propsPtr);
    final sampleRate = _bindings.taglib_audioproperties_samplerate(propsPtr);
    final channels = _bindings.taglib_audioproperties_channels(propsPtr);

    return _AudioProperties(
      duration: lengthSeconds > 0 ? lengthSeconds.toDouble() : null,
      bitrate: bitrate > 0 ? bitrate : null,
      sampleRate: sampleRate > 0 ? sampleRate : null,
      channels: channels > 0 ? channels : null,
    );
  }

  /// Reads the first embedded album art image from the file.
  AlbumArtData? _readAlbumArt(Pointer<TagLib_File> tagFile) {
    final pictureKey = 'PICTURE'.toNativeUtf8();

    try {
      final complexProps =
          _bindings.taglib_complex_property_get(tagFile, pictureKey);

      if (complexProps == nullptr) return null;

      try {
        final pictureData =
            calloc<TagLib_Complex_Property_Picture_Data>();

        try {
          _bindings.taglib_picture_from_complex_property(
            complexProps,
            pictureData,
          );

          if (pictureData.ref.data == nullptr || pictureData.ref.size == 0) {
            return null;
          }

          final mimeType = pictureData.ref.mimeType != nullptr
              ? pictureData.ref.mimeType.toDartString()
              : 'image/jpeg';

          final description = pictureData.ref.description != nullptr
              ? pictureData.ref.description.toDartString()
              : null;

          final pictureType = _parsePictureType(
            pictureData.ref.pictureType != nullptr
                ? pictureData.ref.pictureType.toDartString()
                : null,
          );

          // Copy the image bytes into Dart-managed memory
          final bytes = Uint8List.fromList(
            pictureData.ref.data.asTypedList(pictureData.ref.size),
          );

          return AlbumArtData(
            bytes: bytes,
            mimeType: mimeType,
            description: description,
            type: pictureType,
          );
        } finally {
          calloc.free(pictureData);
        }
      } finally {
        _bindings.taglib_complex_property_free(complexProps);
      }
    } finally {
      malloc.free(pictureKey);
    }
  }

  /// Parses a picture type string from TagLib into an [AlbumArtType].
  AlbumArtType _parsePictureType(String? typeString) {
    if (typeString == null || typeString.isEmpty) {
      return AlbumArtType.frontCover;
    }

    switch (typeString) {
      case 'Front Cover':
        return AlbumArtType.frontCover;
      case 'Back Cover':
        return AlbumArtType.backCover;
      case 'Leaflet Page':
        return AlbumArtType.leafletPage;
      case 'Media':
        return AlbumArtType.media;
      case 'Lead Artist':
        return AlbumArtType.leadArtist;
      case 'Artist':
        return AlbumArtType.artist;
      case 'Conductor':
        return AlbumArtType.conductor;
      case 'Band':
        return AlbumArtType.band;
      case 'Composer':
        return AlbumArtType.composer;
      case 'Lyricist':
        return AlbumArtType.lyricist;
      case 'Recording Location':
        return AlbumArtType.recordingLocation;
      case 'During Recording':
        return AlbumArtType.duringRecording;
      case 'During Performance':
        return AlbumArtType.duringPerformance;
      case 'Band Logo':
        return AlbumArtType.bandLogo;
      case 'Publisher Logo':
        return AlbumArtType.publisherLogo;
      case 'Illustration':
        return AlbumArtType.illustration;
      case 'File Icon':
        return AlbumArtType.fileIcon;
      case 'Other File Icon':
        return AlbumArtType.otherFileIcon;
      case 'Other':
        return AlbumArtType.other;
      default:
        return AlbumArtType.frontCover;
    }
  }

  /// Detects the tag format by reading the file header bytes.
  ///
  /// For MP3s, reads the actual ID3v2 header to determine the version.
  /// For formats with a single tag container type (FLAC, OGG, M4A, etc.),
  /// the format is known from the container spec — not a guess.
  /// Returns null if tags are empty or format can't be determined.
  TagFormat? _detectTagFormat(String extension, Map<String, String> tags) {
    if (tags.isEmpty) return null;

    switch (extension) {
      case '.flac':
      case '.ogg':
      case '.opus':
        // These formats exclusively use Vorbis Comment — it's the only
        // tag container the format spec supports.
        return TagFormat.vorbisComment;
      case '.m4a':
      case '.mp4':
      case '.aac':
        // MP4 container exclusively uses iTunes-style atoms.
        return TagFormat.mp4Atoms;
      case '.wma':
        // ASF container exclusively uses ASF metadata.
        return TagFormat.asf;
      case '.ape':
        // APE files exclusively use APE tags.
        return TagFormat.apeTag;
      default:
        // For MP3, WAV, and others where multiple tag formats are possible,
        // we can't determine the version without reading the header.
        // Return unknown — the Id3ReaderService fallback does header detection.
        return TagFormat.unknown;
    }
  }

  /// Reads a NULL-terminated array of UTF-8 string pointers into a Dart list.
  List<String> _readStringArray(Pointer<Pointer<Utf8>> array) {
    if (array == nullptr) return [];
    final results = <String>[];
    var i = 0;
    while (array[i] != nullptr) {
      results.add(array[i].toDartString());
      i++;
    }
    return results;
  }
}

/// Internal holder for audio property values.
class _AudioProperties {
  const _AudioProperties({
    this.duration,
    this.bitrate,
    this.sampleRate,
    this.channels,
  });

  final double? duration;
  final int? bitrate;
  final int? sampleRate;
  final int? channels;
}
