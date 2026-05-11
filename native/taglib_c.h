/***************************************************************************
    copyright            : (C) 2003 by Scott Wheeler
    email                : wheeler@kde.org
 ***************************************************************************/

/***************************************************************************
 *   This library is free software; you can redistribute it and/or modify  *
 *   it  under the terms of the GNU Lesser General Public License version  *
 *   2.1 as published by the Free Software Foundation.                     *
 *                                                                         *
 *   This library is distributed in the hope that it will be useful, but   *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   Lesser General Public License for more details.                       *
 *                                                                         *
 *   You should have received a copy of the GNU Lesser General Public      *
 *   License along with this library; if not, write to the Free Software   *
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  *
 *   USA                                                                   *
 ***************************************************************************/

#ifndef TAGLIB_TAG_C
#define TAGLIB_TAG_C

#ifndef DO_NOT_DOCUMENT

#ifdef __cplusplus
extern "C" {
#endif

#if defined(TAGLIB_STATIC)
#define TAGLIB_C_EXPORT
#elif defined(_WIN32) || defined(_WIN64)
#ifdef MAKE_TAGLIB_C_LIB
#define TAGLIB_C_EXPORT __declspec(dllexport)
#else
#define TAGLIB_C_EXPORT __declspec(dllimport)
#endif
#elif defined(__GNUC__) && (__GNUC__ > 4 || __GNUC__ == 4 && __GNUC_MINOR__ >= 1)
#define TAGLIB_C_EXPORT __attribute__ ((visibility("default")))
#else
#define TAGLIB_C_EXPORT
#endif

#ifndef BOOL
#define BOOL int
#endif

typedef struct { int dummy; } TagLib_File;
typedef struct { int dummy; } TagLib_Tag;
typedef struct { int dummy; } TagLib_AudioProperties;
typedef struct { int dummy; } TagLib_IOStream;

TAGLIB_C_EXPORT void taglib_set_strings_unicode(BOOL unicode);
TAGLIB_C_EXPORT void taglib_set_string_management_enabled(BOOL management);
TAGLIB_C_EXPORT void taglib_free(void* pointer);

// Stream API
TAGLIB_C_EXPORT TagLib_IOStream *taglib_memory_iostream_new(const char *data, unsigned int size);
TAGLIB_C_EXPORT void taglib_iostream_free(TagLib_IOStream *stream);

// File API
typedef enum {
  TagLib_File_MPEG,
  TagLib_File_OggVorbis,
  TagLib_File_FLAC,
  TagLib_File_MPC,
  TagLib_File_OggFlac,
  TagLib_File_WavPack,
  TagLib_File_Speex,
  TagLib_File_TrueAudio,
  TagLib_File_MP4,
  TagLib_File_ASF,
  TagLib_File_AIFF,
  TagLib_File_WAV,
  TagLib_File_APE,
  TagLib_File_IT,
  TagLib_File_Mod,
  TagLib_File_S3M,
  TagLib_File_XM,
  TagLib_File_Opus,
  TagLib_File_DSF,
  TagLib_File_DSDIFF,
  TagLib_File_SHORTEN,
  TagLib_File_MATROSKA
} TagLib_File_Type;

TAGLIB_C_EXPORT TagLib_File *taglib_file_new(const char *filename);
TAGLIB_C_EXPORT TagLib_File *taglib_file_new_type(const char *filename, TagLib_File_Type type);
TAGLIB_C_EXPORT TagLib_File *taglib_file_new_iostream(TagLib_IOStream *stream);
TAGLIB_C_EXPORT void taglib_file_free(TagLib_File *file);
TAGLIB_C_EXPORT BOOL taglib_file_is_valid(const TagLib_File *file);
TAGLIB_C_EXPORT TagLib_Tag *taglib_file_tag(const TagLib_File *file);
TAGLIB_C_EXPORT const TagLib_AudioProperties *taglib_file_audioproperties(const TagLib_File *file);
TAGLIB_C_EXPORT BOOL taglib_file_save(TagLib_File *file);

// Tag API
TAGLIB_C_EXPORT char *taglib_tag_title(const TagLib_Tag *tag);
TAGLIB_C_EXPORT char *taglib_tag_artist(const TagLib_Tag *tag);
TAGLIB_C_EXPORT char *taglib_tag_album(const TagLib_Tag *tag);
TAGLIB_C_EXPORT char *taglib_tag_comment(const TagLib_Tag *tag);
TAGLIB_C_EXPORT char *taglib_tag_genre(const TagLib_Tag *tag);
TAGLIB_C_EXPORT unsigned int taglib_tag_year(const TagLib_Tag *tag);
TAGLIB_C_EXPORT unsigned int taglib_tag_track(const TagLib_Tag *tag);
TAGLIB_C_EXPORT void taglib_tag_set_title(TagLib_Tag *tag, const char *title);
TAGLIB_C_EXPORT void taglib_tag_set_artist(TagLib_Tag *tag, const char *artist);
TAGLIB_C_EXPORT void taglib_tag_set_album(TagLib_Tag *tag, const char *album);
TAGLIB_C_EXPORT void taglib_tag_set_comment(TagLib_Tag *tag, const char *comment);
TAGLIB_C_EXPORT void taglib_tag_set_genre(TagLib_Tag *tag, const char *genre);
TAGLIB_C_EXPORT void taglib_tag_set_year(TagLib_Tag *tag, unsigned int year);
TAGLIB_C_EXPORT void taglib_tag_set_track(TagLib_Tag *tag, unsigned int track);
TAGLIB_C_EXPORT void taglib_tag_free_strings(void);

// Audio Properties API
TAGLIB_C_EXPORT int taglib_audioproperties_length(const TagLib_AudioProperties *audioProperties);
TAGLIB_C_EXPORT int taglib_audioproperties_bitrate(const TagLib_AudioProperties *audioProperties);
TAGLIB_C_EXPORT int taglib_audioproperties_samplerate(const TagLib_AudioProperties *audioProperties);
TAGLIB_C_EXPORT int taglib_audioproperties_channels(const TagLib_AudioProperties *audioProperties);

// ID3v2 convenience
typedef enum {
  TagLib_ID3v2_Latin1,
  TagLib_ID3v2_UTF16,
  TagLib_ID3v2_UTF16BE,
  TagLib_ID3v2_UTF8
} TagLib_ID3v2_Encoding;

TAGLIB_C_EXPORT void taglib_id3v2_set_default_text_encoding(TagLib_ID3v2_Encoding encoding);

// Properties API
TAGLIB_C_EXPORT void taglib_property_set(TagLib_File *file, const char *prop, const char *value);
TAGLIB_C_EXPORT void taglib_property_set_append(TagLib_File *file, const char *prop, const char *value);
TAGLIB_C_EXPORT char** taglib_property_keys(const TagLib_File *file);
TAGLIB_C_EXPORT char** taglib_property_get(const TagLib_File *file, const char *prop);
TAGLIB_C_EXPORT void taglib_property_free(char **props);

// Complex Properties API
typedef enum {
  TagLib_Variant_Void,
  TagLib_Variant_Bool,
  TagLib_Variant_Int,
  TagLib_Variant_UInt,
  TagLib_Variant_LongLong,
  TagLib_Variant_ULongLong,
  TagLib_Variant_Double,
  TagLib_Variant_String,
  TagLib_Variant_StringList,
  TagLib_Variant_ByteVector
} TagLib_Variant_Type;

typedef struct {
  TagLib_Variant_Type type;
  unsigned int size;
  union {
    char *stringValue;
    char *byteVectorValue;
    char **stringListValue;
    BOOL boolValue;
    int intValue;
    unsigned int uIntValue;
    long long longLongValue;
    unsigned long long uLongLongValue;
    double doubleValue;
  } value;
} TagLib_Variant;

typedef struct {
  char *key;
  TagLib_Variant value;
} TagLib_Complex_Property_Attribute;

typedef struct {
  char *mimeType;
  char *description;
  char *pictureType;
  char *data;
  unsigned int size;
} TagLib_Complex_Property_Picture_Data;

TAGLIB_C_EXPORT BOOL taglib_complex_property_set(
  TagLib_File *file, const char *key,
  const TagLib_Complex_Property_Attribute **value);
TAGLIB_C_EXPORT BOOL taglib_complex_property_set_append(
  TagLib_File *file, const char *key,
  const TagLib_Complex_Property_Attribute **value);
TAGLIB_C_EXPORT char** taglib_complex_property_keys(const TagLib_File *file);
TAGLIB_C_EXPORT TagLib_Complex_Property_Attribute*** taglib_complex_property_get(
  const TagLib_File *file, const char *key);
TAGLIB_C_EXPORT void taglib_picture_from_complex_property(
  TagLib_Complex_Property_Attribute*** properties,
  TagLib_Complex_Property_Picture_Data *picture);
TAGLIB_C_EXPORT void taglib_complex_property_free_keys(char **keys);
TAGLIB_C_EXPORT void taglib_complex_property_free(
  TagLib_Complex_Property_Attribute ***props);

#ifdef __cplusplus
}
#endif
#endif
#endif
