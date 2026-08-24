import 'dart:io';
import 'dart:typed_data';

/// Pure-Dart ID3v1 / ID3v1.1 codec operating on the trailing 128 bytes of
/// an MP3 file.
///
/// Layout (offset, length):
///   0   3  "TAG"
///   3   30  Title
///   33  30  Artist
///   63  30  Album
///   93  4   Year
///   97  30  Comment — v1.1 reserves byte 125 as zero + track at 126
///   127 1   Genre (byte index into the ID3v1 genre list; 255 = unknown)
class Id3v1Codec {
  Id3v1Codec._();

  /// The ID3v1 tag signature.
  static const String signature = 'TAG';

  static const int tagSize = 128;

  /// Field length limits (v1.1: comment shrinks to 28 when a track is set).
  static const int titleLength = 30;
  static const int artistLength = 30;
  static const int albumLength = 30;
  static const int yearLength = 4;
  static const int commentLengthV10 = 30;
  static const int commentLengthV11 = 28;

  /// Parses the last [tagSize] bytes of an MP3.
  ///
  /// Returns null when the block does not start with "TAG".
  static Map<String, String>? parse(Uint8List tail) {
    if (tail.length < tagSize) return null;
    if (_asciiAt(tail, 0, 3) != signature) return null;

    final tags = <String, String>{
      'title': _trimmedString(tail, 3, titleLength),
      'artist': _trimmedString(tail, 33, artistLength),
      'album': _trimmedString(tail, 63, albumLength),
      'year': _trimmedString(tail, 93, yearLength),
    };

    // v1.1 detection: zero byte at 125 and non-zero track at 126.
    final hasTrack = tail[125] == 0x00 && tail[126] != 0x00;
    if (hasTrack) {
      tags['trackNumber'] = '${tail[126]}';
      tags['comment'] = _trimmedString(tail, 97, commentLengthV11);
    } else {
      tags['comment'] = _trimmedString(tail, 97, commentLengthV10);
    }

    tags.removeWhere((_, v) => v.isEmpty);
    return tags;
  }

  /// Reads the trailing block from [path] and parses it.
  ///
  /// Returns null when the file is shorter than 128 bytes or has no tag.
  static Map<String, String>? readFromFile(String path) {
    final file = File(path);
    final length = file.lengthSync();
    if (length < tagSize) return null;
    final raf = file.openSync(mode: FileMode.read);
    try {
      raf.setPositionSync(length - tagSize);
      return parse(raf.readSync(tagSize));
    } finally {
      raf.closeSync();
    }
  }

  /// Builds a full 128-byte ID3v1.1 block from [tags].
  ///
  /// Recognized keys: title, artist, album, year, comment, trackNumber.
  /// Values longer than their field are truncated; the genre byte is
  /// always 255 ("unknown") because we do not ship the numeric genre list.
  static Uint8List build(Map<String, String> tags) {
    final block = Uint8List(tagSize);
    _writeAscii(block, 0, signature, 3);

    final track = int.tryParse(tags['trackNumber'] ?? '');
    final useV11 = track != null && track > 0 && track <= 255;

    _writeField(block, 3, titleLength, tags['title'] ?? '');
    _writeField(block, 33, artistLength, tags['artist'] ?? '');
    _writeField(block, 63, albumLength, tags['album'] ?? '');
    _writeField(block, 93, yearLength, tags['year'] ?? '');

    if (useV11) {
      _writeField(block, 97, commentLengthV11, tags['comment'] ?? '');
      block[125] = 0x00;
      block[126] = track;
    } else {
      _writeField(block, 97, commentLengthV10, tags['comment'] ?? '');
      // Bytes 125-126 stay zero; 127 is genre below.
    }

    block[127] = 0xFF; // Genre unknown
    return block;
  }

  /// Appends or replaces the ID3v1 block on the MP3 at [path] with [tags].
  ///
  /// Returns true when a pre-existing tag was replaced, false when one was
  /// appended. Throws if the file does not exist (append mode must not
  /// silently resurrect deleted files).
  static bool writeToFile(String path, Map<String, String> tags) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('File does not exist', path);
    }
    final raf = file.openSync(mode: FileMode.append);
    try {
      final hadTag = _hasTag(file);
      if (hadTag) {
        raf.truncateSync(file.lengthSync() - tagSize);
      }
      raf.writeFromSync(build(tags));
      return hadTag;
    } finally {
      raf.closeSync();
    }
  }

  /// Removes the ID3v1 block if present. Returns whether it existed.
  static bool stripFromFile(String path) {
    final file = File(path);
    if (!_hasTag(file)) return false;
    final raf = file.openSync(mode: FileMode.append);
    try {
      raf.truncateSync(file.lengthSync() - tagSize);
      return true;
    } finally {
      raf.closeSync();
    }
  }

  static bool _hasTag(File file) {
    final length = file.lengthSync();
    if (length < tagSize) return false;
    final raf = file.openSync(mode: FileMode.read);
    try {
      // Signature sits at the START of the trailing 128-byte block.
      raf.setPositionSync(length - tagSize);
      final sig = raf.readSync(3);
      return sig[0] == 0x54 && sig[1] == 0x41 && sig[2] == 0x47; // 'TAG'
    } finally {
      raf.closeSync();
    }
  }

  static void _writeField(
    Uint8List block,
    int offset,
    int maxLength,
    String value,
  ) {
    final encoded = latin1SafeBytes(value, maxLength);
    block.setRange(offset, offset + encoded.length, encoded);
  }

  static void _writeAscii(
    Uint8List block,
    int offset,
    String value,
    int maxLength,
  ) {
    for (var i = 0; i < maxLength; i++) {
      block[offset + i] = i < value.length ? value.codeUnitAt(i) : 0x00;
    }
  }

  /// Encodes to Latin-1, mapping unmappable characters to '?' so ID3v1's
  /// single-byte fields never throw (ID3v1 cannot represent Unicode).
  static Uint8List latin1SafeBytes(String value, int maxLength) {
    final clamped =
        value.length > maxLength ? value.substring(0, maxLength) : value;
    final out = Uint8List(clamped.length);
    for (var i = 0; i < clamped.length; i++) {
      final unit = clamped.codeUnitAt(i);
      out[i] = unit <= 0xFF ? unit : 0x3F; // '?'
    }
    return out;
  }

  static String _asciiAt(Uint8List data, int offset, int length) =>
      String.fromCharCodes(data.sublist(offset, offset + length));

  static String _trimmedString(Uint8List data, int offset, int maxLength) {
    var end = offset + maxLength;
    while (end > offset && (data[end - 1] == 0x00 || data[end - 1] == 0x20)) {
      end--;
    }
    return String.fromCharCodes(data.sublist(offset, end));
  }
}
