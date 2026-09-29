import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../../features/settings/data/models/tag_write_options.dart';
import '../../../features/tools/data/multi_value.dart';
import '../../models/audio_file.dart';
import '../tag_reader_service.dart';
import 'atomic_write_manager.dart';
import 'backup_manager.dart';
import 'tag_property_mapper.dart';
import 'taglib_bindings.g.dart';
import 'validation_engine.dart';
import 'win32_short_path.dart';

/// Writes audio file tags using TagLib via FFI bindings.
///
/// Implements atomic writes (temp-file-then-rename), optional backup creation,
/// and post-write validation to ensure data integrity.
class TagLibWriterService implements TagWriterService {
  /// Creates a [TagLibWriterService] with the given dependencies.
  TagLibWriterService(
    this._bindings,
    this._backupManager,
    this._validator, {
    required TagWriteOptions Function() getWriteOptions,
    bool Function()? isPreserveTimestampEnabled,
  }) : _getWriteOptions = getWriteOptions,
       _isPreserveTimestampEnabled = isPreserveTimestampEnabled;

  final TagLibBindings _bindings;
  final BackupManager _backupManager;
  final ValidationEngine _validator;
  final TagWriteOptions Function() _getWriteOptions;
  final bool Function()? _isPreserveTimestampEnabled;
  final AtomicWriteManager _atomicWriteManager = AtomicWriteManager();

  @override
  Future<void> writeTags(String path, Map<String, String> tags) async {
    _assertFileExists(path);
    await _backupManager.createBackupIfEnabled(path);
    DateTime? originalMtime;
    if (_isPreserveTimestampEnabled?.call() ?? false) {
      try {
        originalMtime = File(path).statSync().modified;
      } catch (_) {}
    }
    final options = _getWriteOptions();

    // Set the default text encoding for ID3v2 frames before writing.
    // Handle v2.3 + UTF-8 incompatibility by falling back to UTF-16.
    final encodingByte =
        (options.id3v2Version.numericVersion == 3 &&
            options.encoding.id3v2EncodingByte == 3)
        ? 1 // Fall back to UTF-16 for ID3v2.3
        : options.encoding.id3v2EncodingByte;
    _bindings.taglib_id3v2_set_default_text_encoding(encodingByte);

    await _atomicWriteManager.writeAtomic(path, (tempPath) async {
      final effectivePath = _resolveNativePath(tempPath);
      final nativePath = effectivePath.toNativeUtf8();
      Pointer<TagLib_File> file = nullptr;

      try {
        file = _bindings.taglib_file_new(nativePath);

        if (file == nullptr) {
          throw TagWriteException('Failed to open file for writing', path);
        }

        _writeProperties(file, tags);

        final result = _bindings.taglib_file_save(file);
        if (result == 0) {
          throw TagWriteException('TagLib failed to save file', path);
        }
      } finally {
        malloc.free(nativePath);
        if (file != nullptr) {
          _bindings.taglib_file_free(file);
        }
      }
    });

    await _validator.validate(path, tags);

    if (originalMtime != null) {
      try {
        await File(path).setLastModified(originalMtime);
      } catch (_) {}
    }
  }

  @override
  Future<void> writeAlbumArt(String path, AlbumArtData art) async {
    _assertFileExists(path);
    await _backupManager.createBackupIfEnabled(path);
    DateTime? originalMtime;
    if (_isPreserveTimestampEnabled?.call() ?? false) {
      try {
        originalMtime = File(path).statSync().modified;
      } catch (_) {}
    }

    await _atomicWriteManager.writeAtomic(path, (tempPath) async {
      final effectivePath = _resolveNativePath(tempPath);
      final nativePath = effectivePath.toNativeUtf8();
      Pointer<TagLib_File> file = nullptr;
      PictureAttributes? attrs;

      try {
        file = _bindings.taglib_file_new(nativePath);

        if (file == nullptr) {
          throw TagWriteException(
            'Failed to open file for album art writing',
            path,
          );
        }

        attrs = PictureAttributeBuilder.build(
          imageBytes: art.bytes,
          mimeType: art.mimeType,
          description: art.description ?? '',
          pictureType: _albumArtTypeToString(art.type),
        );

        final pictureKey = 'PICTURE'.toNativeUtf8();
        try {
          _bindings.taglib_complex_property_set(
            file,
            pictureKey,
            attrs.pointer,
          );
        } finally {
          malloc.free(pictureKey);
        }

        final result = _bindings.taglib_file_save(file);
        if (result == 0) {
          throw TagWriteException(
            'TagLib failed to save file after album art write',
            path,
          );
        }
      } finally {
        malloc.free(nativePath);
        attrs?.dispose();
        if (file != nullptr) {
          _bindings.taglib_file_free(file);
        }
      }
    });

    if (originalMtime != null) {
      try {
        await File(path).setLastModified(originalMtime);
      } catch (_) {}
    }
  }

  @override
  Future<void> removeAlbumArt(String path) async {
    _assertFileExists(path);
    await _backupManager.createBackupIfEnabled(path);
    DateTime? originalMtime;
    if (_isPreserveTimestampEnabled?.call() ?? false) {
      try {
        originalMtime = File(path).statSync().modified;
      } catch (_) {}
    }

    await _atomicWriteManager.writeAtomic(path, (tempPath) async {
      final effectivePath = _resolveNativePath(tempPath);
      final nativePath = effectivePath.toNativeUtf8();
      Pointer<TagLib_File> file = nullptr;

      try {
        file = _bindings.taglib_file_new(nativePath);

        if (file == nullptr) {
          throw TagWriteException(
            'Failed to open file for album art removal',
            path,
          );
        }

        final pictureKey = 'PICTURE'.toNativeUtf8();
        try {
          _bindings.taglib_complex_property_set(file, pictureKey, nullptr);
        } finally {
          malloc.free(pictureKey);
        }

        final result = _bindings.taglib_file_save(file);
        if (result == 0) {
          throw TagWriteException(
            'TagLib failed to save file after album art removal',
            path,
          );
        }
      } finally {
        malloc.free(nativePath);
        if (file != nullptr) {
          _bindings.taglib_file_free(file);
        }
      }
    });

    if (originalMtime != null) {
      try {
        await File(path).setLastModified(originalMtime);
      } catch (_) {}
    }
  }

  @override
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  ) async {
    final results = <TagWriteResult>[];

    for (final entry in fileTagsMap.entries) {
      final filePath = entry.key;
      final tags = entry.value;

      try {
        await writeTags(filePath, tags);
        results.add(TagWriteResult(path: filePath, success: true));
      } catch (e) {
        results.add(
          TagWriteResult(path: filePath, success: false, error: e.toString()),
        );
      }
    }

    return results;
  }

  /// Writes tag properties to the open TagLib file handle.
  ///
  /// Handles track/disc number formatting (combining number and total as
  /// "3/12") and clearing properties when the value is empty.
  ///
  /// Multi-value fields are written as genuine repeated properties: the
  /// existing value is cleared and each value appended in turn, using
  /// `taglib_property_set_append`. Writing the joined display string through
  /// `taglib_property_set` instead would collapse "Artist A; Artist B" into
  /// one literal property, which is how a second artist gets silently
  /// destroyed on the next save.
  void _writeProperties(Pointer<TagLib_File> file, Map<String, String> tags) {
    // Process track/disc totals alongside their numbers
    final processedTags = _preprocessTrackDiscFields(tags);

    for (final entry in processedTags.entries) {
      final appField = entry.key;
      final value = entry.value;

      // Skip total fields — they are merged into the number field
      if (appField == 'trackTotal' || appField == 'discTotal') {
        continue;
      }

      final tagLibKey = TagPropertyMapper.toTagLibKey(appField);
      if (tagLibKey == null) continue;

      final keyNative = tagLibKey.toNativeUtf8();
      try {
        if (value.isEmpty) {
          // Clear the property by passing nullptr as value
          _bindings.taglib_property_set(file, keyNative, nullptr);
        } else if (isMultiValueField(appField)) {
          _writeMultiValue(file, keyNative, value, appField);
        } else {
          final valueNative = value.toNativeUtf8();
          try {
            _bindings.taglib_property_set(file, keyNative, valueNative);
          } finally {
            malloc.free(valueNative);
          }
        }
      } finally {
        malloc.free(keyNative);
      }
    }
  }

  /// Replaces [key] with one property per value in [joinedValue].
  void _writeMultiValue(
    Pointer<TagLib_File> file,
    Pointer<Utf8> keyNative,
    String joinedValue,
    String appField,
  ) {
    final values = MultiValue.parse(
      joinedValue,
      appField,
      splitSingleValueFields: true,
    );

    // Clear first: appending to whatever was already there would merge the
    // new values with the old ones instead of replacing them.
    _bindings.taglib_property_set(file, keyNative, nullptr);
    if (values.isEmpty) return;

    for (final value in values) {
      final valueNative = value.toNativeUtf8();
      try {
        _bindings.taglib_property_set_append(file, keyNative, valueNative);
      } finally {
        malloc.free(valueNative);
      }
    }
  }

  /// Preprocesses track/disc number fields to combine number and total.
  ///
  /// If both `trackNumber` and `trackTotal` are present, formats as "3/12".
  /// Same for `discNumber` and `discTotal`.
  Map<String, String> _preprocessTrackDiscFields(Map<String, String> tags) {
    final result = Map<String, String>.of(tags);

    // Combine trackNumber with trackTotal if both present
    if (result.containsKey('trackNumber')) {
      final number = result['trackNumber']!;
      final total = result['trackTotal'];
      if (number.isNotEmpty && total != null && total.isNotEmpty) {
        result['trackNumber'] = TagPropertyMapper.formatTrackNumber(
          number,
          total,
        );
      }
    }

    // Combine discNumber with discTotal if both present
    if (result.containsKey('discNumber')) {
      final number = result['discNumber']!;
      final total = result['discTotal'];
      if (number.isNotEmpty && total != null && total.isNotEmpty) {
        result['discNumber'] = TagPropertyMapper.formatTrackNumber(
          number,
          total,
        );
      }
    }

    return result;
  }

  /// Maps an [AlbumArtType] enum value to the TagLib picture type string.
  String _albumArtTypeToString(AlbumArtType type) {
    switch (type) {
      case AlbumArtType.other:
        return 'Other';
      case AlbumArtType.fileIcon:
        return 'File Icon';
      case AlbumArtType.otherFileIcon:
        return 'Other File Icon';
      case AlbumArtType.frontCover:
        return 'Front Cover';
      case AlbumArtType.backCover:
        return 'Back Cover';
      case AlbumArtType.leafletPage:
        return 'Leaflet Page';
      case AlbumArtType.media:
        return 'Media';
      case AlbumArtType.leadArtist:
        return 'Lead Artist';
      case AlbumArtType.artist:
        return 'Artist';
      case AlbumArtType.conductor:
        return 'Conductor';
      case AlbumArtType.band:
        return 'Band';
      case AlbumArtType.composer:
        return 'Composer';
      case AlbumArtType.lyricist:
        return 'Lyricist';
      case AlbumArtType.recordingLocation:
        return 'Recording Location';
      case AlbumArtType.duringRecording:
        return 'During Recording';
      case AlbumArtType.duringPerformance:
        return 'During Performance';
      case AlbumArtType.movieCapture:
        return 'Movie Capture';
      case AlbumArtType.brightColouredFish:
        return 'Bright Coloured Fish';
      case AlbumArtType.illustration:
        return 'Illustration';
      case AlbumArtType.bandLogo:
        return 'Band Logo';
      case AlbumArtType.publisherLogo:
        return 'Publisher Logo';
    }
  }

  /// Asserts that the file at [path] exists, throwing if not.
  void _assertFileExists(String path) {
    if (!File(path).existsSync()) {
      throw TagWriteException('File does not exist', path);
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
}
