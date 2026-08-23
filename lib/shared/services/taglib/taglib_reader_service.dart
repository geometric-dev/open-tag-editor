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
import 'win32_short_path.dart';

/// Reads audio file tags using TagLib via FFI bindings.
///
/// This implementation uses the TagLib Properties API to read all tag fields
/// in a format-agnostic way, and the Complex Properties API for album art.
class TagLibReaderService implements TagReaderService {
  /// Creates a [TagLibReaderService] with the given [bindings].
  TagLibReaderService(this._bindings) {
    _bindings.taglib_set_strings_unicode(1);
  }

  final TagLibBindings _bindings;

  @override
  Future<AudioFile> readTags(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw TagReadException('File does not exist', path);
    }

    // On Windows, paths with non-ASCII characters (emoji, CJK, etc.) can't
    // be opened by TagLib's fopen-based API. Use the 8.3 short path instead.
    final effectivePath = _resolveNativePath(path);
    final nativePath = effectivePath.toNativeUtf8();
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
      final tagFormat = _detectTagFormat(
        p.extension(path).toLowerCase(),
        tags,
        file,
      );

      final stat = file.statSync();
      final isReadOnly = _isFileReadOnly(file);

      return AudioFile(
        path: path,
        filename: p.basename(path),
        extension: p.extension(path).toLowerCase(),
        fileSize: stat.size,
        tags: tags,
        originalTags: Map<String, String>.unmodifiable(tags),
        albumArt: albumArt,
        duration: audioProps.duration,
        bitrate: audioProps.bitrate,
        sampleRate: audioProps.sampleRate,
        channels: audioProps.channels,
        tagFormat: tagFormat,
        isReadOnly: isReadOnly,
      );
    } finally {
      malloc.free(nativePath);
      if (tagFile != nullptr) {
        _bindings.taglib_file_free(tagFile);
      }
    }
  }

  /// Resolves a file path to one that TagLib's C API can open.
  ///
  /// On Windows, if the path contains non-ASCII characters, converts it
  /// to the 8.3 short path format (which is always ASCII). Falls back to
  /// the original path if short path conversion fails.
  String _resolveNativePath(String path) {
    if (!Platform.isWindows) return path;
    if (!Win32ShortPath.hasNonAsciiChars(path)) return path;
    return Win32ShortPath.getShortPath(path) ?? path;
  }

  /// Checks whether a file is read-only on the filesystem.
  ///
  /// Attempts to open the file for append access without modifying it.
  /// If the open fails, the file is considered read-only.
  static bool _isFileReadOnly(File file) {
    try {
      final raf = file.openSync(mode: FileMode.writeOnlyAppend);
      raf.closeSync();
      return false;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<List<AudioFile>> readTagsBatch(List<String> paths) async {
    final results = <AudioFile>[];

    for (final path in paths) {
      try {
        final audioFile = await readTags(path);
        results.add(audioFile);
      } catch (e) {
        // On failure, include file with empty tags and readError
        final file = File(path);
        results.add(AudioFile(
          path: path,
          filename: p.basename(path),
          extension: p.extension(path).toLowerCase(),
          fileSize: file.existsSync() ? file.statSync().size : 0,
          isReadOnly: file.existsSync() ? _isFileReadOnly(file) : false,
          readError: e.toString(),
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
  TagFormat? _detectTagFormat(
    String extension,
    Map<String, String> tags,
    File file,
  ) {
    if (tags.isEmpty) return null;

    switch (extension) {
      case '.mp3':
        // Read the first 10 bytes to check for an ID3v2 header.
        // ID3v2 header: "ID3" (3 bytes) + version major (1 byte) + ...
        return _detectMp3TagFormat(file);
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
        return TagFormat.unknown;
    }
  }

  /// Detects the ID3 tag version for an MP3 file by reading the header.
  ///
  /// Checks for an ID3v2 header ("ID3" magic bytes) and reads the version
  /// byte. Falls back to ID3v1 if no ID3v2 header is found but tags exist.
  TagFormat _detectMp3TagFormat(File file) {
    try {
      final raf = file.openSync(mode: FileMode.read);
      try {
        final header = raf.readSync(10);
        if (header.length >= 4 &&
            header[0] == 0x49 && // 'I'
            header[1] == 0x44 && // 'D'
            header[2] == 0x33) { // '3'
          final version = header[3];
          return version == 4 ? TagFormat.id3v2_4 : TagFormat.id3v2_3;
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      // If we can't read the header, fall back gracefully.
    }
    // No ID3v2 header found but tags were read — must be ID3v1.
    return TagFormat.id3v1;
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
