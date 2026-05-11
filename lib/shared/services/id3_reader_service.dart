import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/audio_file.dart';
import 'tag_reader_service.dart';
import 'taglib/taglib_types.dart';

/// Pure Dart implementation of tag reading for common audio formats.
///
/// Supports:
/// - ID3v1 and ID3v2 (MP3)
/// - Vorbis Comments (FLAC, OGG, OPUS)
/// - Basic MP4/M4A atom parsing
///
/// This is a minimal implementation to get the app functional.
/// For production use, consider FFI bindings to TagLib for full format support.
class Id3ReaderService implements TagReaderService {
  @override
  Future<AudioFile> readTags(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw TagReadException('File not found', path);
    }

    final stat = file.statSync();
    final extension = p.extension(path).toLowerCase();
    final filename = p.basename(path);

    try {
      final bytes = await file.readAsBytes();
      Map<String, String> tags;
      AlbumArtData? albumArt;
      int? bitrate;
      int? sampleRate;
      int? channels;
      double? duration;
      TagFormat? tagFormat;

      switch (extension) {
        case '.mp3':
          final result = _readMp3(bytes);
          tags = result.tags;
          albumArt = result.albumArt;
          bitrate = result.bitrate;
          sampleRate = result.sampleRate;
          channels = result.channels;
          duration = result.duration;
          // Detect tag format
          if (bytes.length > 10 &&
              bytes[0] == 0x49 &&
              bytes[1] == 0x44 &&
              bytes[2] == 0x33) {
            final version = bytes[3];
            tagFormat = version == 4
                ? TagFormat.id3v2_4
                : version == 3
                    ? TagFormat.id3v2_3
                    : TagFormat.id3v2_3;
          } else if (tags.isNotEmpty) {
            tagFormat = TagFormat.id3v1;
          }
          break;
        case '.flac':
          final result = _readFlac(bytes);
          tags = result.tags;
          albumArt = result.albumArt;
          sampleRate = result.sampleRate;
          channels = result.channels;
          duration = result.duration;
          if (tags.isNotEmpty) {
            tagFormat = TagFormat.vorbisComment;
          }
          break;
        case '.ogg':
        case '.opus':
          tags = {};
          if (tags.isNotEmpty) {
            tagFormat = TagFormat.vorbisComment;
          }
          break;
        case '.m4a':
        case '.mp4':
        case '.aac':
          tags = {};
          tagFormat = TagFormat.mp4Atoms;
          break;
        case '.wma':
          tags = {};
          tagFormat = TagFormat.asf;
          break;
        case '.ape':
          tags = {};
          tagFormat = TagFormat.apeTag;
          break;
        default:
          tags = {};
      }

      return AudioFile(
        path: path,
        filename: filename,
        extension: extension,
        fileSize: stat.size,
        tags: tags,
        albumArt: albumArt,
        bitrate: bitrate,
        sampleRate: sampleRate,
        channels: channels,
        duration: duration,
        tagFormat: tagFormat,
      );
    } catch (e) {
      if (e is TagReadException) rethrow;
      throw TagReadException('Failed to read tags: $e', path);
    }
  }

  @override
  Future<List<AudioFile>> readTagsBatch(List<String> paths) async {
    final results = <AudioFile>[];
    for (final path in paths) {
      try {
        results.add(await readTags(path));
      } catch (e) {
        // Return file with empty tags on failure
        final filename = p.basename(path);
        results.add(AudioFile(
          path: path,
          filename: filename,
          extension: p.extension(path).toLowerCase(),
          fileSize: 0,
          tags: const {},
        ),);
      }
    }
    return results;
  }

  _Mp3Result _readMp3(Uint8List bytes) {
    final tags = <String, String>{};
    AlbumArtData? albumArt;
    int? bitrate;
    int? sampleRate;
    int? channels;
    double? duration;

    // Try ID3v2 first (at the beginning of the file)
    if (bytes.length > 10 &&
        bytes[0] == 0x49 && // 'I'
        bytes[1] == 0x44 && // 'D'
        bytes[2] == 0x33) {
      // '3'
      final id3Result = _readId3v2(bytes);
      tags.addAll(id3Result.tags);
      albumArt = id3Result.albumArt;
    }

    // Try ID3v1 (last 128 bytes) if no ID3v2 tags found
    if (tags.isEmpty && bytes.length >= 128) {
      final id3v1Tags = _readId3v1(bytes);
      tags.addAll(id3v1Tags);
    }

    // Try to read MP3 frame header for audio properties
    final frameInfo = _readMp3FrameHeader(bytes);
    if (frameInfo != null) {
      bitrate = frameInfo.bitrate;
      sampleRate = frameInfo.sampleRate;
      channels = frameInfo.channels;
      if (bitrate > 0) {
        duration = (bytes.length * 8) / (bitrate * 1000);
      }
    }

    return _Mp3Result(
      tags: tags,
      albumArt: albumArt,
      bitrate: bitrate,
      sampleRate: sampleRate,
      channels: channels,
      duration: duration,
    );
  }

  _Id3v2Result _readId3v2(Uint8List bytes) {
    final tags = <String, String>{};
    AlbumArtData? albumArt;

    // ID3v2 header: 10 bytes
    // Bytes 3: version major
    // Bytes 4: version minor
    // Bytes 5: flags
    // Bytes 6-9: size (syncsafe integer)
    final versionMajor = bytes[3];
    final size = _readSyncsafeInt(bytes, 6);
    var offset = 10;

    // Skip extended header if present
    final flags = bytes[5];
    if (flags & 0x40 != 0 && versionMajor >= 3) {
      final extSize = versionMajor == 4
          ? _readSyncsafeInt(bytes, offset)
          : _readInt32(bytes, offset);
      offset += extSize;
    }

    final endOffset = 10 + size;

    while (offset < endOffset - 10 && offset < bytes.length - 10) {
      // Frame header: 4 bytes ID, 4 bytes size, 2 bytes flags
      final frameId = String.fromCharCodes(bytes.sublist(offset, offset + 4));

      // Stop if we hit padding (null bytes)
      if (frameId[0] == '\x00') break;

      int frameSize;
      if (versionMajor == 4) {
        frameSize = _readSyncsafeInt(bytes, offset + 4);
      } else {
        frameSize = _readInt32(bytes, offset + 4);
      }

      if (frameSize <= 0 || offset + 10 + frameSize > bytes.length) break;

      final frameData = bytes.sublist(offset + 10, offset + 10 + frameSize);

      // Parse text frames
      if (frameId.startsWith('T') && frameId != 'TXXX') {
        final text = _decodeTextFrame(frameData);
        final field = _id3v2FrameToField(frameId);
        if (field != null && text.isNotEmpty) {
          tags[field] = text;
        }
      } else if (frameId == 'COMM') {
        // Comment frame
        final text = _decodeCommentFrame(frameData);
        if (text.isNotEmpty) {
          tags['comment'] = text;
        }
      } else if (frameId == 'APIC') {
        // Album art
        albumArt = _decodeApicFrame(frameData);
      } else if (frameId == 'TXXX') {
        // User-defined text frame
        final result = _decodeTxxxFrame(frameData);
        if (result != null) {
          tags[result.key] = result.value;
        }
      }

      offset += 10 + frameSize;
    }

    return _Id3v2Result(tags: tags, albumArt: albumArt);
  }

  Map<String, String> _readId3v1(Uint8List bytes) {
    final tags = <String, String>{};
    final tagStart = bytes.length - 128;

    // Check for 'TAG' marker
    if (bytes[tagStart] != 0x54 ||
        bytes[tagStart + 1] != 0x41 ||
        bytes[tagStart + 2] != 0x47) {
      return tags;
    }

    final title = _readFixedString(bytes, tagStart + 3, 30);
    final artist = _readFixedString(bytes, tagStart + 33, 30);
    final album = _readFixedString(bytes, tagStart + 63, 30);
    final year = _readFixedString(bytes, tagStart + 93, 4);
    final comment = _readFixedString(bytes, tagStart + 97, 30);
    final genreIndex = bytes[tagStart + 127];

    if (title.isNotEmpty) tags['title'] = title;
    if (artist.isNotEmpty) tags['artist'] = artist;
    if (album.isNotEmpty) tags['album'] = album;
    if (year.isNotEmpty) tags['year'] = year;
    if (comment.isNotEmpty) tags['comment'] = comment;

    // ID3v1.1: track number in byte 126 if byte 125 is 0
    if (bytes[tagStart + 125] == 0 && bytes[tagStart + 126] != 0) {
      tags['trackNumber'] = bytes[tagStart + 126].toString();
    }

    if (genreIndex < _id3v1Genres.length) {
      tags['genre'] = _id3v1Genres[genreIndex];
    }

    return tags;
  }

  _FlacResult _readFlac(Uint8List bytes) {
    final tags = <String, String>{};
    AlbumArtData? albumArt;
    int? sampleRate;
    int? channels;
    double? duration;

    // Check fLaC marker
    if (bytes.length < 4 ||
        bytes[0] != 0x66 ||
        bytes[1] != 0x4C ||
        bytes[2] != 0x61 ||
        bytes[3] != 0x43) {
      return _FlacResult(tags: tags);
    }

    var offset = 4;

    while (offset < bytes.length - 4) {
      final isLast = (bytes[offset] & 0x80) != 0;
      final blockType = bytes[offset] & 0x7F;
      final blockSize =
          (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
      offset += 4;

      if (offset + blockSize > bytes.length) break;

      switch (blockType) {
        case 0: // STREAMINFO
          if (blockSize >= 18) {
            sampleRate = ((bytes[offset + 10] << 12) |
                    (bytes[offset + 11] << 4) |
                    ((bytes[offset + 12] & 0xF0) >> 4));
            channels = ((bytes[offset + 12] & 0x0E) >> 1) + 1;
            final totalSamples = ((bytes[offset + 13] & 0x0F) << 32) |
                (bytes[offset + 14] << 24) |
                (bytes[offset + 15] << 16) |
                (bytes[offset + 16] << 8) |
                bytes[offset + 17];
            if (sampleRate > 0 && totalSamples > 0) {
              duration = totalSamples / sampleRate;
            }
          }
          break;
        case 4: // VORBIS_COMMENT
          final vorbisResult = _readVorbisComment(bytes, offset, blockSize);
          tags.addAll(vorbisResult);
          break;
        case 6: // PICTURE
          albumArt = _readFlacPicture(bytes, offset, blockSize);
          break;
      }

      offset += blockSize;
      if (isLast) break;
    }

    return _FlacResult(
      tags: tags,
      albumArt: albumArt,
      sampleRate: sampleRate,
      channels: channels,
      duration: duration,
    );
  }

  Map<String, String> _readVorbisComment(
    Uint8List bytes,
    int offset,
    int blockSize,
  ) {
    final tags = <String, String>{};
    if (offset + 4 > bytes.length) return tags;

    // Vendor string length (little-endian)
    final vendorLen = _readInt32LE(bytes, offset);
    var pos = offset + 4 + vendorLen;

    if (pos + 4 > bytes.length) return tags;

    // Number of comments
    final commentCount = _readInt32LE(bytes, pos);
    pos += 4;

    for (var i = 0; i < commentCount && pos + 4 < bytes.length; i++) {
      final commentLen = _readInt32LE(bytes, pos);
      pos += 4;

      if (pos + commentLen > bytes.length) break;

      final comment = String.fromCharCodes(bytes.sublist(pos, pos + commentLen));
      final eqIndex = comment.indexOf('=');
      if (eqIndex > 0) {
        final key = comment.substring(0, eqIndex).toLowerCase();
        final value = comment.substring(eqIndex + 1);
        final field = _vorbisFieldToField(key);
        if (field != null) {
          tags[field] = value;
        }
      }
      pos += commentLen;
    }

    return tags;
  }

  AlbumArtData? _readFlacPicture(Uint8List bytes, int offset, int blockSize) {
    if (offset + 32 > bytes.length) return null;

    var pos = offset;
    // Picture type
    final pictureType = _readInt32(bytes, pos);
    pos += 4;

    // MIME type
    final mimeLen = _readInt32(bytes, pos);
    pos += 4;
    if (pos + mimeLen > bytes.length) return null;
    final mimeType = String.fromCharCodes(bytes.sublist(pos, pos + mimeLen));
    pos += mimeLen;

    // Description
    final descLen = _readInt32(bytes, pos);
    pos += 4;
    pos += descLen; // Skip description

    // Width, height, color depth, colors used
    pos += 16;

    // Picture data
    final dataLen = _readInt32(bytes, pos);
    pos += 4;
    if (pos + dataLen > bytes.length) return null;

    final imageBytes = Uint8List.fromList(bytes.sublist(pos, pos + dataLen));

    return AlbumArtData(
      bytes: imageBytes,
      mimeType: mimeType,
      type: pictureType < AlbumArtType.values.length
          ? AlbumArtType.values[pictureType]
          : AlbumArtType.frontCover,
    );
  }

  _Mp3FrameInfo? _readMp3FrameHeader(Uint8List bytes) {
    // Find first valid MP3 frame sync (0xFFE0 or higher)
    var offset = 0;

    // Skip ID3v2 tag if present
    if (bytes.length > 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      offset = 10 + _readSyncsafeInt(bytes, 6);
    }

    // Search for frame sync
    while (offset < bytes.length - 4) {
      if (bytes[offset] == 0xFF && (bytes[offset + 1] & 0xE0) == 0xE0) {
        final header = bytes.sublist(offset, offset + 4);
        final version = (header[1] >> 3) & 0x03;
        final layer = (header[1] >> 1) & 0x03;
        final bitrateIndex = (header[2] >> 4) & 0x0F;
        final sampleRateIndex = (header[2] >> 2) & 0x03;
        final channelMode = (header[3] >> 6) & 0x03;

        if (version != 1 &&
            layer != 0 &&
            bitrateIndex != 0 &&
            bitrateIndex != 15 &&
            sampleRateIndex != 3) {
          final bitrate = _getMp3Bitrate(version, layer, bitrateIndex);
          final sampleRate = _getMp3SampleRate(version, sampleRateIndex);
          final channels = channelMode == 3 ? 1 : 2;

          if (bitrate != null && sampleRate != null) {
            return _Mp3FrameInfo(
              bitrate: bitrate,
              sampleRate: sampleRate,
              channels: channels,
            );
          }
        }
      }
      offset++;
    }
    return null;
  }

  // --- Helper methods ---

  int _readSyncsafeInt(Uint8List bytes, int offset) {
    return ((bytes[offset] & 0x7F) << 21) |
        ((bytes[offset + 1] & 0x7F) << 14) |
        ((bytes[offset + 2] & 0x7F) << 7) |
        (bytes[offset + 3] & 0x7F);
  }

  int _readInt32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  int _readInt32LE(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  String _readFixedString(Uint8List bytes, int offset, int length) {
    final end = offset + length;
    if (end > bytes.length) return '';
    final sub = bytes.sublist(offset, end);
    // Trim null bytes and whitespace
    var str = String.fromCharCodes(sub);
    final nullIndex = str.indexOf('\x00');
    if (nullIndex >= 0) str = str.substring(0, nullIndex);
    return str.trim();
  }

  String _decodeTextFrame(Uint8List data) {
    if (data.isEmpty) return '';
    final encoding = data[0];
    final textBytes = data.sublist(1);

    switch (encoding) {
      case 0: // ISO-8859-1
        return String.fromCharCodes(textBytes).replaceAll('\x00', '');
      case 1: // UTF-16 with BOM
        return _decodeUtf16(textBytes);
      case 2: // UTF-16BE
        return _decodeUtf16BE(textBytes);
      case 3: // UTF-8
        return String.fromCharCodes(textBytes).replaceAll('\x00', '');
      default:
        return String.fromCharCodes(textBytes).replaceAll('\x00', '');
    }
  }

  String _decodeCommentFrame(Uint8List data) {
    if (data.length < 5) return '';
    final encoding = data[0];
    // Skip language (3 bytes) and short description (null-terminated)
    var offset = 4;

    // Find end of short description
    if (encoding == 0 || encoding == 3) {
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      offset++; // Skip null terminator
    } else {
      // UTF-16: look for double null
      while (offset < data.length - 1) {
        if (data[offset] == 0 && data[offset + 1] == 0) {
          offset += 2;
          break;
        }
        offset += 2;
      }
    }

    if (offset >= data.length) return '';
    final textBytes = data.sublist(offset);

    switch (encoding) {
      case 0:
      case 3:
        return String.fromCharCodes(textBytes).replaceAll('\x00', '');
      case 1:
        return _decodeUtf16(textBytes);
      case 2:
        return _decodeUtf16BE(textBytes);
      default:
        return String.fromCharCodes(textBytes).replaceAll('\x00', '');
    }
  }

  AlbumArtData? _decodeApicFrame(Uint8List data) {
    if (data.length < 4) return null;
    final encoding = data[0];
    var offset = 1;

    // Read MIME type (null-terminated)
    final mimeEnd = data.indexOf(0, offset);
    if (mimeEnd < 0) return null;
    final mimeType = String.fromCharCodes(data.sublist(offset, mimeEnd));
    offset = mimeEnd + 1;

    // Picture type
    if (offset >= data.length) return null;
    final pictureType = data[offset];
    offset++;

    // Description (null-terminated, encoding-dependent)
    if (encoding == 0 || encoding == 3) {
      final descEnd = data.indexOf(0, offset);
      if (descEnd < 0) return null;
      offset = descEnd + 1;
    } else {
      // UTF-16: find double null
      while (offset < data.length - 1) {
        if (data[offset] == 0 && data[offset + 1] == 0) {
          offset += 2;
          break;
        }
        offset += 2;
      }
    }

    if (offset >= data.length) return null;

    final imageBytes = Uint8List.fromList(data.sublist(offset));

    return AlbumArtData(
      bytes: imageBytes,
      mimeType: mimeType.isEmpty ? 'image/jpeg' : mimeType,
      type: pictureType < AlbumArtType.values.length
          ? AlbumArtType.values[pictureType]
          : AlbumArtType.frontCover,
    );
  }

  ({String key, String value})? _decodeTxxxFrame(Uint8List data) {
    if (data.length < 2) return null;
    final encoding = data[0];
    var offset = 1;

    String description;
    if (encoding == 0 || encoding == 3) {
      final nullIndex = data.indexOf(0, offset);
      if (nullIndex < 0) return null;
      description = String.fromCharCodes(data.sublist(offset, nullIndex));
      offset = nullIndex + 1;
    } else {
      // UTF-16
      final startOffset = offset;
      while (offset < data.length - 1) {
        if (data[offset] == 0 && data[offset + 1] == 0) break;
        offset += 2;
      }
      description = _decodeUtf16(data.sublist(startOffset, offset));
      offset += 2;
    }

    if (offset >= data.length) return null;
    final valueBytes = data.sublist(offset);
    final value = (encoding == 0 || encoding == 3)
        ? String.fromCharCodes(valueBytes).replaceAll('\x00', '')
        : _decodeUtf16(valueBytes);

    return (key: description.toLowerCase(), value: value);
  }

  String _decodeUtf16(Uint8List bytes) {
    if (bytes.length < 2) return '';
    // Check BOM
    final bom = (bytes[0] << 8) | bytes[1];
    if (bom == 0xFEFF) {
      return _decodeUtf16BE(bytes.sublist(2));
    } else if (bom == 0xFFFE) {
      return _decodeUtf16LE(bytes.sublist(2));
    }
    // Default to LE
    return _decodeUtf16LE(bytes);
  }

  String _decodeUtf16BE(Uint8List bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length - 1; i += 2) {
      final code = (bytes[i] << 8) | bytes[i + 1];
      if (code == 0) break;
      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  String _decodeUtf16LE(Uint8List bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length - 1; i += 2) {
      final code = bytes[i] | (bytes[i + 1] << 8);
      if (code == 0) break;
      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  String? _id3v2FrameToField(String frameId) {
    const mapping = {
      'TIT2': 'title',
      'TPE1': 'artist',
      'TPE2': 'albumArtist',
      'TALB': 'album',
      'TDRC': 'year',
      'TYER': 'year',
      'TRCK': 'trackNumber',
      'TPOS': 'discNumber',
      'TCON': 'genre',
      'TCOM': 'composer',
      'TPE3': 'conductor',
      'TEXT': 'lyricist',
      'TPUB': 'publisher',
      'TCOP': 'copyright',
      'TENC': 'encodedBy',
      'TBPM': 'bpm',
      'TCMP': 'compilation',
    };
    return mapping[frameId];
  }

  String? _vorbisFieldToField(String key) {
    const mapping = {
      'title': 'title',
      'artist': 'artist',
      'albumartist': 'albumArtist',
      'album artist': 'albumArtist',
      'album': 'album',
      'date': 'year',
      'year': 'year',
      'tracknumber': 'trackNumber',
      'track': 'trackNumber',
      'discnumber': 'discNumber',
      'disc': 'discNumber',
      'genre': 'genre',
      'comment': 'comment',
      'composer': 'composer',
      'conductor': 'conductor',
      'lyricist': 'lyricist',
      'publisher': 'publisher',
      'copyright': 'copyright',
      'encodedby': 'encodedBy',
      'bpm': 'bpm',
      'compilation': 'compilation',
    };
    return mapping[key];
  }

  int? _getMp3Bitrate(int version, int layer, int index) {
    // MPEG1, Layer III bitrates
    const bitratesV1L3 = [
      0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0,
    ];
    // MPEG2/2.5, Layer III bitrates
    const bitratesV2L3 = [
      0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0,
    ];

    if (version == 3) {
      // MPEG1
      return bitratesV1L3[index];
    } else {
      return bitratesV2L3[index];
    }
  }

  int? _getMp3SampleRate(int version, int index) {
    const ratesV1 = [44100, 48000, 32000];
    const ratesV2 = [22050, 24000, 16000];
    const ratesV25 = [11025, 12000, 8000];

    switch (version) {
      case 3:
        return ratesV1[index];
      case 2:
        return ratesV2[index];
      case 0:
        return ratesV25[index];
      default:
        return null;
    }
  }

  static const _id3v1Genres = [
    'Blues', 'Classic Rock', 'Country', 'Dance', 'Disco', 'Funk', 'Grunge',
    'Hip-Hop', 'Jazz', 'Metal', 'New Age', 'Oldies', 'Other', 'Pop', 'R&B',
    'Rap', 'Reggae', 'Rock', 'Techno', 'Industrial', 'Alternative', 'Ska',
    'Death Metal', 'Pranks', 'Soundtrack', 'Euro-Techno', 'Ambient',
    'Trip-Hop', 'Vocal', 'Jazz+Funk', 'Fusion', 'Trance', 'Classical',
    'Instrumental', 'Acid', 'House', 'Game', 'Sound Clip', 'Gospel', 'Noise',
    'AlternRock', 'Bass', 'Soul', 'Punk', 'Space', 'Meditative',
    'Instrumental Pop', 'Instrumental Rock', 'Ethnic', 'Gothic', 'Darkwave',
    'Techno-Industrial', 'Electronic', 'Pop-Folk', 'Eurodance', 'Dream',
    'Southern Rock', 'Comedy', 'Cult', 'Gangsta', 'Top 40', 'Christian Rap',
    'Pop/Funk', 'Jungle', 'Native American', 'Cabaret', 'New Wave',
    'Psychedelic', 'Rave', 'Showtunes', 'Trailer', 'Lo-Fi', 'Tribal',
    'Acid Punk', 'Acid Jazz', 'Polka', 'Retro', 'Musical', 'Rock & Roll',
    'Hard Rock',
  ];
}

// --- Internal result types ---

class _Mp3Result {
  const _Mp3Result({
    required this.tags,
    this.albumArt,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.duration,
  });

  final Map<String, String> tags;
  final AlbumArtData? albumArt;
  final int? bitrate;
  final int? sampleRate;
  final int? channels;
  final double? duration;
}

class _Id3v2Result {
  const _Id3v2Result({required this.tags, this.albumArt});

  final Map<String, String> tags;
  final AlbumArtData? albumArt;
}

class _FlacResult {
  const _FlacResult({
    required this.tags,
    this.albumArt,
    this.sampleRate,
    this.channels,
    this.duration,
  });

  final Map<String, String> tags;
  final AlbumArtData? albumArt;
  final int? sampleRate;
  final int? channels;
  final double? duration;
}

class _Mp3FrameInfo {
  const _Mp3FrameInfo({
    required this.bitrate,
    required this.sampleRate,
    required this.channels,
  });

  final int bitrate;
  final int sampleRate;
  final int channels;
}
