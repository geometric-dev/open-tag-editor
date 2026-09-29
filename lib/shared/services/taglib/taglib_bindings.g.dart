// ignore_for_file: type=lint
// Generated FFI bindings for TagLib C API.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// --- Opaque Structs ---

final class TagLib_File extends Opaque {}

final class TagLib_Tag extends Opaque {}

final class TagLib_AudioProperties extends Opaque {}

final class TagLib_IOStream extends Opaque {}

// --- Enums ---

abstract class TagLib_File_Type {
  static const int TagLib_File_MPEG = 0;
  static const int TagLib_File_OggVorbis = 1;
  static const int TagLib_File_FLAC = 2;
  static const int TagLib_File_MPC = 3;
  static const int TagLib_File_OggFlac = 4;
  static const int TagLib_File_WavPack = 5;
  static const int TagLib_File_Speex = 6;
  static const int TagLib_File_TrueAudio = 7;
  static const int TagLib_File_MP4 = 8;
  static const int TagLib_File_ASF = 9;
  static const int TagLib_File_AIFF = 10;
  static const int TagLib_File_WAV = 11;
  static const int TagLib_File_APE = 12;
  static const int TagLib_File_IT = 13;
  static const int TagLib_File_Mod = 14;
  static const int TagLib_File_S3M = 15;
  static const int TagLib_File_XM = 16;
  static const int TagLib_File_Opus = 17;
  static const int TagLib_File_DSF = 18;
  static const int TagLib_File_DSDIFF = 19;
  static const int TagLib_File_SHORTEN = 20;
  static const int TagLib_File_MATROSKA = 21;
}

abstract class TagLib_Variant_Type {
  static const int TagLib_Variant_Void = 0;
  static const int TagLib_Variant_Bool = 1;
  static const int TagLib_Variant_Int = 2;
  static const int TagLib_Variant_UInt = 3;
  static const int TagLib_Variant_LongLong = 4;
  static const int TagLib_Variant_ULongLong = 5;
  static const int TagLib_Variant_Double = 6;
  static const int TagLib_Variant_String = 7;
  static const int TagLib_Variant_StringList = 8;
  static const int TagLib_Variant_ByteVector = 9;
}

abstract class TagLib_ID3v2_Encoding {
  static const int TagLib_ID3v2_Latin1 = 0;
  static const int TagLib_ID3v2_UTF16 = 1;
  static const int TagLib_ID3v2_UTF16BE = 2;
  static const int TagLib_ID3v2_UTF8 = 3;
}

/// Short-form variant type constants for use in PictureAttributeBuilder.
abstract class TagLibVariantType {
  static const int void_ = 0;
  static const int bool_ = 1;
  static const int int_ = 2;
  static const int uInt = 3;
  static const int longLong = 4;
  static const int uLongLong = 5;
  static const int double_ = 6;
  static const int string = 7;
  static const int stringList = 8;
  static const int byteVector = 9;
}

// --- Complex Property Structs ---

final class TagLib_Complex_Property_Picture_Data extends Struct {
  external Pointer<Utf8> mimeType;
  external Pointer<Utf8> description;
  external Pointer<Utf8> pictureType;

  /// Raw image bytes (not a UTF-8 string). Use `.cast<Uint8>()` to access.
  external Pointer<Uint8> data;
  @Uint32()
  external int size;
}

/// Represents TagLib_Variant. The value field is a union — we access it
/// as a raw pointer and interpret based on the type field.
///
/// C layout: int type (4 bytes) + unsigned int size (4 bytes) + union (8 bytes).
/// Total: 16 bytes on 64-bit platforms.
final class TagLib_Variant extends Struct {
  @Int32()
  external int type;

  @Uint32()
  external int size;

  /// Union value — interpret based on [type].
  /// For String/ByteVector: cast to Pointer<Utf8>/Pointer<Uint8>
  external Pointer<Void> value;
}

/// Represents TagLib_Complex_Property_Attribute (key + TagLib_Variant value).
final class TagLib_Complex_Property_Attribute extends Struct {
  external Pointer<Utf8> key;
  external TagLib_Variant value;
}

// --- Bindings Class ---

class TagLibBindings {
  final DynamicLibrary _dylib;

  TagLibBindings(DynamicLibrary dylib) : _dylib = dylib;

  Pointer<T> Function<T extends NativeType>(String name) get _lookup =>
      _dylib.lookup;

  // ===== Global Configuration API =====

  late final _taglib_set_strings_unicode = _dylib
      .lookup<NativeFunction<Void Function(Int32)>>(
        'taglib_set_strings_unicode',
      );
  late final taglib_set_strings_unicode = _taglib_set_strings_unicode
      .asFunction<void Function(int)>();

  late final _taglib_set_string_management_enabled = _dylib
      .lookup<NativeFunction<Void Function(Int32)>>(
        'taglib_set_string_management_enabled',
      );
  late final taglib_set_string_management_enabled =
      _taglib_set_string_management_enabled.asFunction<void Function(int)>();

  late final _taglib_free = _dylib
      .lookup<NativeFunction<Void Function(Pointer<Void>)>>('taglib_free');
  late final taglib_free = _taglib_free
      .asFunction<void Function(Pointer<Void>)>();

  // ===== File API =====

  late final _taglib_file_new = _dylib
      .lookup<NativeFunction<Pointer<TagLib_File> Function(Pointer<Utf8>)>>(
        'taglib_file_new',
      );
  late final taglib_file_new = _taglib_file_new
      .asFunction<Pointer<TagLib_File> Function(Pointer<Utf8>)>();

  late final _taglib_file_new_type = _dylib
      .lookup<
        NativeFunction<Pointer<TagLib_File> Function(Pointer<Utf8>, Int32)>
      >('taglib_file_new_type');
  late final taglib_file_new_type = _taglib_file_new_type
      .asFunction<Pointer<TagLib_File> Function(Pointer<Utf8>, int)>();

  late final _taglib_file_free = _dylib
      .lookup<NativeFunction<Void Function(Pointer<TagLib_File>)>>(
        'taglib_file_free',
      );
  late final taglib_file_free = _taglib_file_free
      .asFunction<void Function(Pointer<TagLib_File>)>();

  late final _taglib_file_is_valid = _dylib
      .lookup<NativeFunction<Int32 Function(Pointer<TagLib_File>)>>(
        'taglib_file_is_valid',
      );
  late final taglib_file_is_valid = _taglib_file_is_valid
      .asFunction<int Function(Pointer<TagLib_File>)>();

  late final _taglib_file_tag = _dylib
      .lookup<
        NativeFunction<Pointer<TagLib_Tag> Function(Pointer<TagLib_File>)>
      >('taglib_file_tag');
  late final taglib_file_tag = _taglib_file_tag
      .asFunction<Pointer<TagLib_Tag> Function(Pointer<TagLib_File>)>();

  late final _taglib_file_audioproperties = _dylib
      .lookup<
        NativeFunction<
          Pointer<TagLib_AudioProperties> Function(Pointer<TagLib_File>)
        >
      >('taglib_file_audioproperties');
  late final taglib_file_audioproperties = _taglib_file_audioproperties
      .asFunction<
        Pointer<TagLib_AudioProperties> Function(Pointer<TagLib_File>)
      >();

  late final _taglib_file_save = _dylib
      .lookup<NativeFunction<Int32 Function(Pointer<TagLib_File>)>>(
        'taglib_file_save',
      );
  late final taglib_file_save = _taglib_file_save
      .asFunction<int Function(Pointer<TagLib_File>)>();

  // ===== Tag API =====

  late final _taglib_tag_title = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>>(
        'taglib_tag_title',
      );
  late final taglib_tag_title = _taglib_tag_title
      .asFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>();

  late final _taglib_tag_artist = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>>(
        'taglib_tag_artist',
      );
  late final taglib_tag_artist = _taglib_tag_artist
      .asFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>();

  late final _taglib_tag_album = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>>(
        'taglib_tag_album',
      );
  late final taglib_tag_album = _taglib_tag_album
      .asFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>();

  late final _taglib_tag_comment = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>>(
        'taglib_tag_comment',
      );
  late final taglib_tag_comment = _taglib_tag_comment
      .asFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>();

  late final _taglib_tag_genre = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>>(
        'taglib_tag_genre',
      );
  late final taglib_tag_genre = _taglib_tag_genre
      .asFunction<Pointer<Utf8> Function(Pointer<TagLib_Tag>)>();

  late final _taglib_tag_year = _dylib
      .lookup<NativeFunction<Uint32 Function(Pointer<TagLib_Tag>)>>(
        'taglib_tag_year',
      );
  late final taglib_tag_year = _taglib_tag_year
      .asFunction<int Function(Pointer<TagLib_Tag>)>();

  late final _taglib_tag_track = _dylib
      .lookup<NativeFunction<Uint32 Function(Pointer<TagLib_Tag>)>>(
        'taglib_tag_track',
      );
  late final taglib_tag_track = _taglib_tag_track
      .asFunction<int Function(Pointer<TagLib_Tag>)>();

  late final _taglib_tag_set_title = _dylib
      .lookup<
        NativeFunction<Void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>
      >('taglib_tag_set_title');
  late final taglib_tag_set_title = _taglib_tag_set_title
      .asFunction<void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>();

  late final _taglib_tag_set_artist = _dylib
      .lookup<
        NativeFunction<Void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>
      >('taglib_tag_set_artist');
  late final taglib_tag_set_artist = _taglib_tag_set_artist
      .asFunction<void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>();

  late final _taglib_tag_set_album = _dylib
      .lookup<
        NativeFunction<Void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>
      >('taglib_tag_set_album');
  late final taglib_tag_set_album = _taglib_tag_set_album
      .asFunction<void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>();

  late final _taglib_tag_set_comment = _dylib
      .lookup<
        NativeFunction<Void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>
      >('taglib_tag_set_comment');
  late final taglib_tag_set_comment = _taglib_tag_set_comment
      .asFunction<void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>();

  late final _taglib_tag_set_genre = _dylib
      .lookup<
        NativeFunction<Void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>
      >('taglib_tag_set_genre');
  late final taglib_tag_set_genre = _taglib_tag_set_genre
      .asFunction<void Function(Pointer<TagLib_Tag>, Pointer<Utf8>)>();

  late final _taglib_tag_set_year = _dylib
      .lookup<NativeFunction<Void Function(Pointer<TagLib_Tag>, Uint32)>>(
        'taglib_tag_set_year',
      );
  late final taglib_tag_set_year = _taglib_tag_set_year
      .asFunction<void Function(Pointer<TagLib_Tag>, int)>();

  late final _taglib_tag_set_track = _dylib
      .lookup<NativeFunction<Void Function(Pointer<TagLib_Tag>, Uint32)>>(
        'taglib_tag_set_track',
      );
  late final taglib_tag_set_track = _taglib_tag_set_track
      .asFunction<void Function(Pointer<TagLib_Tag>, int)>();

  late final _taglib_tag_free_strings = _dylib
      .lookup<NativeFunction<Void Function()>>('taglib_tag_free_strings');
  late final taglib_tag_free_strings = _taglib_tag_free_strings
      .asFunction<void Function()>();

  // ===== Audio Properties API =====

  late final _taglib_audioproperties_length = _dylib
      .lookup<NativeFunction<Int32 Function(Pointer<TagLib_AudioProperties>)>>(
        'taglib_audioproperties_length',
      );
  late final taglib_audioproperties_length = _taglib_audioproperties_length
      .asFunction<int Function(Pointer<TagLib_AudioProperties>)>();

  late final _taglib_audioproperties_bitrate = _dylib
      .lookup<NativeFunction<Int32 Function(Pointer<TagLib_AudioProperties>)>>(
        'taglib_audioproperties_bitrate',
      );
  late final taglib_audioproperties_bitrate = _taglib_audioproperties_bitrate
      .asFunction<int Function(Pointer<TagLib_AudioProperties>)>();

  late final _taglib_audioproperties_samplerate = _dylib
      .lookup<NativeFunction<Int32 Function(Pointer<TagLib_AudioProperties>)>>(
        'taglib_audioproperties_samplerate',
      );
  late final taglib_audioproperties_samplerate =
      _taglib_audioproperties_samplerate
          .asFunction<int Function(Pointer<TagLib_AudioProperties>)>();

  late final _taglib_audioproperties_channels = _dylib
      .lookup<NativeFunction<Int32 Function(Pointer<TagLib_AudioProperties>)>>(
        'taglib_audioproperties_channels',
      );
  late final taglib_audioproperties_channels = _taglib_audioproperties_channels
      .asFunction<int Function(Pointer<TagLib_AudioProperties>)>();

  // ===== ID3v2 API =====

  late final _taglib_id3v2_set_default_text_encoding = _dylib
      .lookup<NativeFunction<Void Function(Int32)>>(
        'taglib_id3v2_set_default_text_encoding',
      );
  late final taglib_id3v2_set_default_text_encoding =
      _taglib_id3v2_set_default_text_encoding.asFunction<void Function(int)>();

  // ===== Properties API =====

  late final _taglib_property_set = _dylib
      .lookup<
        NativeFunction<
          Void Function(Pointer<TagLib_File>, Pointer<Utf8>, Pointer<Utf8>)
        >
      >('taglib_property_set');
  late final taglib_property_set = _taglib_property_set
      .asFunction<
        void Function(Pointer<TagLib_File>, Pointer<Utf8>, Pointer<Utf8>)
      >();

  late final _taglib_property_set_append = _dylib
      .lookup<
        NativeFunction<
          Void Function(Pointer<TagLib_File>, Pointer<Utf8>, Pointer<Utf8>)
        >
      >('taglib_property_set_append');
  late final taglib_property_set_append = _taglib_property_set_append
      .asFunction<
        void Function(Pointer<TagLib_File>, Pointer<Utf8>, Pointer<Utf8>)
      >();

  late final _taglib_property_keys = _dylib
      .lookup<
        NativeFunction<Pointer<Pointer<Utf8>> Function(Pointer<TagLib_File>)>
      >('taglib_property_keys');
  late final taglib_property_keys = _taglib_property_keys
      .asFunction<Pointer<Pointer<Utf8>> Function(Pointer<TagLib_File>)>();

  late final _taglib_property_get = _dylib
      .lookup<
        NativeFunction<
          Pointer<Pointer<Utf8>> Function(Pointer<TagLib_File>, Pointer<Utf8>)
        >
      >('taglib_property_get');
  late final taglib_property_get = _taglib_property_get
      .asFunction<
        Pointer<Pointer<Utf8>> Function(Pointer<TagLib_File>, Pointer<Utf8>)
      >();

  late final _taglib_property_free = _dylib
      .lookup<NativeFunction<Void Function(Pointer<Pointer<Utf8>>)>>(
        'taglib_property_free',
      );
  late final taglib_property_free = _taglib_property_free
      .asFunction<void Function(Pointer<Pointer<Utf8>>)>();

  // ===== Complex Properties API =====

  late final _taglib_complex_property_set = _dylib
      .lookup<
        NativeFunction<
          Int32 Function(
            Pointer<TagLib_File>,
            Pointer<Utf8>,
            Pointer<Pointer<Void>>,
          )
        >
      >('taglib_complex_property_set');
  late final taglib_complex_property_set = _taglib_complex_property_set
      .asFunction<
        int Function(
          Pointer<TagLib_File>,
          Pointer<Utf8>,
          Pointer<Pointer<Void>>,
        )
      >();

  late final _taglib_complex_property_keys = _dylib
      .lookup<
        NativeFunction<Pointer<Pointer<Utf8>> Function(Pointer<TagLib_File>)>
      >('taglib_complex_property_keys');
  late final taglib_complex_property_keys = _taglib_complex_property_keys
      .asFunction<Pointer<Pointer<Utf8>> Function(Pointer<TagLib_File>)>();

  late final _taglib_complex_property_get = _dylib
      .lookup<
        NativeFunction<
          Pointer<Pointer<Pointer<Void>>> Function(
            Pointer<TagLib_File>,
            Pointer<Utf8>,
          )
        >
      >('taglib_complex_property_get');
  late final taglib_complex_property_get = _taglib_complex_property_get
      .asFunction<
        Pointer<Pointer<Pointer<Void>>> Function(
          Pointer<TagLib_File>,
          Pointer<Utf8>,
        )
      >();

  late final _taglib_picture_from_complex_property = _dylib
      .lookup<
        NativeFunction<
          Void Function(
            Pointer<Pointer<Pointer<Void>>>,
            Pointer<TagLib_Complex_Property_Picture_Data>,
          )
        >
      >('taglib_picture_from_complex_property');
  late final taglib_picture_from_complex_property =
      _taglib_picture_from_complex_property
          .asFunction<
            void Function(
              Pointer<Pointer<Pointer<Void>>>,
              Pointer<TagLib_Complex_Property_Picture_Data>,
            )
          >();

  late final _taglib_complex_property_free_keys = _dylib
      .lookup<NativeFunction<Void Function(Pointer<Pointer<Utf8>>)>>(
        'taglib_complex_property_free_keys',
      );
  late final taglib_complex_property_free_keys =
      _taglib_complex_property_free_keys
          .asFunction<void Function(Pointer<Pointer<Utf8>>)>();

  late final _taglib_complex_property_free = _dylib
      .lookup<NativeFunction<Void Function(Pointer<Pointer<Pointer<Void>>>)>>(
        'taglib_complex_property_free',
      );
  late final taglib_complex_property_free = _taglib_complex_property_free
      .asFunction<void Function(Pointer<Pointer<Pointer<Void>>>)>();
}

// --- Picture Attribute Builder ---

/// Holds the native attribute array and provides cleanup.
class PictureAttributes {
  PictureAttributes(this.pointer, this._allocations);

  /// The null-terminated attribute array pointer suitable for
  /// passing to taglib_complex_property_set.
  final Pointer<Pointer<Void>> pointer;
  final List<Pointer<NativeType>> _allocations;

  /// Frees all native memory allocated for this attribute array.
  void dispose() {
    for (final ptr in _allocations) {
      malloc.free(ptr);
    }
  }
}

/// Builds a native TagLib_Complex_Property_Attribute array for picture data.
///
/// The caller is responsible for calling [PictureAttributes.dispose] to free
/// all native memory.
class PictureAttributeBuilder {
  /// Builds a null-terminated array of attribute pointers for album art.
  ///
  /// The array contains 4 attributes: data, mimeType, description, pictureType.
  /// Returns a [PictureAttributes] whose [PictureAttributes.pointer] is suitable
  /// for passing to `taglib_complex_property_set`.
  ///
  /// Call [PictureAttributes.dispose] when done to free all allocated memory.
  static PictureAttributes build({
    required Uint8List imageBytes,
    required String mimeType,
    String description = '',
    String pictureType = 'Front Cover',
  }) {
    final allocations = <Pointer<NativeType>>[];

    try {
      // Allocate the attribute array: 4 attributes + 1 null terminator = 5 slots.
      // Each slot is a pointer to a TagLib_Complex_Property_Attribute.
      final attrArray = calloc<Pointer<Void>>(5);
      allocations.add(attrArray);

      // --- Attribute 0: data (ByteVector) ---
      final dataAttr = calloc<TagLib_Complex_Property_Attribute>();
      allocations.add(dataAttr);
      final dataKey = 'data'.toNativeUtf8();
      allocations.add(dataKey);
      dataAttr.ref.key = dataKey;
      dataAttr.ref.value.type = TagLibVariantType.byteVector;
      dataAttr.ref.value.size = imageBytes.length;
      // Copy image bytes into native memory.
      final nativeBytes = malloc<Uint8>(imageBytes.length);
      allocations.add(nativeBytes);
      nativeBytes.asTypedList(imageBytes.length).setAll(0, imageBytes);
      dataAttr.ref.value.value = nativeBytes.cast<Void>();
      attrArray[0] = dataAttr.cast<Void>();

      // --- Attribute 1: mimeType (String) ---
      final mimeAttr = calloc<TagLib_Complex_Property_Attribute>();
      allocations.add(mimeAttr);
      final mimeKey = 'mimeType'.toNativeUtf8();
      allocations.add(mimeKey);
      final mimeValue = mimeType.toNativeUtf8();
      allocations.add(mimeValue);
      mimeAttr.ref.key = mimeKey;
      mimeAttr.ref.value.type = TagLibVariantType.string;
      mimeAttr.ref.value.size = 0;
      mimeAttr.ref.value.value = mimeValue.cast<Void>();
      attrArray[1] = mimeAttr.cast<Void>();

      // --- Attribute 2: description (String) ---
      final descAttr = calloc<TagLib_Complex_Property_Attribute>();
      allocations.add(descAttr);
      final descKey = 'description'.toNativeUtf8();
      allocations.add(descKey);
      final descValue = description.toNativeUtf8();
      allocations.add(descValue);
      descAttr.ref.key = descKey;
      descAttr.ref.value.type = TagLibVariantType.string;
      descAttr.ref.value.size = 0;
      descAttr.ref.value.value = descValue.cast<Void>();
      attrArray[2] = descAttr.cast<Void>();

      // --- Attribute 3: pictureType (String) ---
      final typeAttr = calloc<TagLib_Complex_Property_Attribute>();
      allocations.add(typeAttr);
      final typeKey = 'pictureType'.toNativeUtf8();
      allocations.add(typeKey);
      final typeValue = pictureType.toNativeUtf8();
      allocations.add(typeValue);
      typeAttr.ref.key = typeKey;
      typeAttr.ref.value.type = TagLibVariantType.string;
      typeAttr.ref.value.size = 0;
      typeAttr.ref.value.value = typeValue.cast<Void>();
      attrArray[3] = typeAttr.cast<Void>();

      // --- Null terminator ---
      attrArray[4] = nullptr;

      return PictureAttributes(attrArray, allocations);
    } catch (e) {
      // If anything fails during construction, free what we've allocated.
      for (final ptr in allocations) {
        malloc.free(ptr);
      }
      rethrow;
    }
  }
}
