import 'dart:io';
import 'dart:typed_data';

import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/tag_reader_service.dart';
import 'package:path/path.dart' as p;

/// Test fixture: pure Dart implementation of tag writing.
///
/// Lives under test/ because production writes go through the TagLib FFI
/// writer (TagLibWriterService / DisabledWriterService fallback).
class Id3WriterService implements TagWriterService {
  @override
  Future<void> writeTags(String path, Map<String, String> tags) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw TagWriteException('File not found', path);
    }

    final extension = p.extension(path).toLowerCase();

    switch (extension) {
      case '.mp3':
        await _writeMp3Tags(file, tags);
        break;
      case '.flac':
        await _writeFlacTags(file, tags);
        break;
      default:
        throw TagWriteException(
          'Writing tags for $extension is not yet supported',
          path,
        );
    }
  }

  @override
  Future<void> writeAlbumArt(String path, AlbumArtData art) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw TagWriteException('File not found', path);
    }

    final extension = p.extension(path).toLowerCase();
    switch (extension) {
      case '.mp3':
        await _writeMp3AlbumArt(file, art);
        break;
      default:
        throw TagWriteException(
          'Writing album art for $extension is not yet supported',
          path,
        );
    }
  }

  @override
  Future<void> removeAlbumArt(String path) async {
    // For now, rewrite the file without the APIC frame
    throw TagWriteException('Remove album art not yet implemented', path);
  }

  @override
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  ) async {
    final results = <TagWriteResult>[];
    for (final entry in fileTagsMap.entries) {
      try {
        await writeTags(entry.key, entry.value);
        results.add(TagWriteResult(path: entry.key, success: true));
      } catch (e) {
        results.add(
          TagWriteResult(
            path: entry.key,
            success: false,
            error: e.toString(),
          ),
        );
      }
    }
    return results;
  }

  Future<void> _writeMp3Tags(File file, Map<String, String> tags) async {
    final bytes = await file.readAsBytes();

    // Build new ID3v2.3 tag
    final frames = <Uint8List>[];

    for (final entry in tags.entries) {
      final frameId = _fieldToId3v2Frame(entry.key);
      if (frameId != null && entry.value.isNotEmpty) {
        frames.add(_buildTextFrame(frameId, entry.value));
      }
    }

    if (frames.isEmpty) return;

    // Calculate total frames size
    var framesSize = 0;
    for (final frame in frames) {
      framesSize += frame.length;
    }

    // Add padding (1024 bytes)
    const padding = 1024;
    final tagSize = framesSize + padding;

    // Build ID3v2.3 header
    final header = Uint8List(10);
    header[0] = 0x49; // 'I'
    header[1] = 0x44; // 'D'
    header[2] = 0x33; // '3'
    header[3] = 3; // Version 2.3
    header[4] = 0; // Revision
    header[5] = 0; // Flags
    _writeSyncsafeInt(header, 6, tagSize);

    // Find where audio data starts (skip existing ID3v2 tag)
    var audioStart = 0;
    if (bytes.length > 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      audioStart = 10 + _readSyncsafeInt(bytes, 6);
    }

    // Build new file
    final output = BytesBuilder();
    output.add(header);
    for (final frame in frames) {
      output.add(frame);
    }
    // Add padding
    output.add(Uint8List(padding));
    // Add audio data
    output.add(bytes.sublist(audioStart));

    await file.writeAsBytes(output.toBytes());
  }

  Future<void> _writeMp3AlbumArt(File file, AlbumArtData art) async {
    // Read existing tags, add APIC frame, rewrite
    final bytes = await file.readAsBytes();
    final frames = <Uint8List>[];

    // Preserve existing text frames
    if (bytes.length > 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      final existingFrames = _extractExistingFrames(bytes);
      // Remove existing APIC frames
      frames.addAll(
        existingFrames.where(
          (f) =>
              f.length >= 4 &&
              !(f[0] == 0x41 && f[1] == 0x50 && f[2] == 0x49 && f[3] == 0x43),
        ),
      );
    }

    // Build APIC frame
    frames.add(_buildApicFrame(art));

    // Rebuild file
    var framesSize = 0;
    for (final frame in frames) {
      framesSize += frame.length;
    }

    const padding = 1024;
    final tagSize = framesSize + padding;

    final header = Uint8List(10);
    header[0] = 0x49;
    header[1] = 0x44;
    header[2] = 0x33;
    header[3] = 3;
    header[4] = 0;
    header[5] = 0;
    _writeSyncsafeInt(header, 6, tagSize);

    var audioStart = 0;
    if (bytes.length > 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      audioStart = 10 + _readSyncsafeInt(bytes, 6);
    }

    final output = BytesBuilder();
    output.add(header);
    for (final frame in frames) {
      output.add(frame);
    }
    output.add(Uint8List(padding));
    output.add(bytes.sublist(audioStart));

    await file.writeAsBytes(output.toBytes());
  }

  Future<void> _writeFlacTags(File file, Map<String, String> tags) async {
    final bytes = await file.readAsBytes();

    // Verify FLAC marker
    if (bytes.length < 4 ||
        bytes[0] != 0x66 ||
        bytes[1] != 0x4C ||
        bytes[2] != 0x61 ||
        bytes[3] != 0x43) {
      throw TagWriteException('Not a valid FLAC file', file.path);
    }

    // Find and replace the VORBIS_COMMENT block
    var offset = 4;
    final blocks = <_FlacBlock>[];
    var vorbisBlockIndex = -1;

    while (offset < bytes.length - 4) {
      final isLast = (bytes[offset] & 0x80) != 0;
      final blockType = bytes[offset] & 0x7F;
      final blockSize = (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];

      blocks.add(
        _FlacBlock(
          type: blockType,
          isLast: isLast,
          data: bytes.sublist(offset + 4, offset + 4 + blockSize),
        ),
      );

      if (blockType == 4) {
        vorbisBlockIndex = blocks.length - 1;
      }

      offset += 4 + blockSize;
      if (isLast) break;
    }

    // Build new Vorbis Comment block
    final vorbisData = _buildVorbisComment(tags);

    if (vorbisBlockIndex >= 0) {
      blocks[vorbisBlockIndex] = _FlacBlock(
        type: 4,
        isLast: blocks[vorbisBlockIndex].isLast,
        data: vorbisData,
      );
    } else {
      // Insert before the last block
      if (blocks.isNotEmpty) {
        blocks.last = _FlacBlock(
          type: blocks.last.type,
          isLast: false,
          data: blocks.last.data,
        );
      }
      blocks.add(_FlacBlock(type: 4, isLast: true, data: vorbisData));
    }

    // Rebuild file
    final output = BytesBuilder();
    output.add(bytes.sublist(0, 4)); // fLaC marker

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final headerByte = (block.isLast ? 0x80 : 0x00) | (block.type & 0x7F);
      output.addByte(headerByte);
      output.addByte((block.data.length >> 16) & 0xFF);
      output.addByte((block.data.length >> 8) & 0xFF);
      output.addByte(block.data.length & 0xFF);
      output.add(block.data);
    }

    // Add audio frames
    output.add(bytes.sublist(offset));

    await file.writeAsBytes(output.toBytes());
  }

  Uint8List _buildTextFrame(String frameId, String value) {
    // UTF-8 encoding (0x03)
    final textBytes = value.codeUnits;
    final frameSize = 1 + textBytes.length; // encoding byte + text

    final frame = Uint8List(10 + frameSize);
    // Frame ID
    for (var i = 0; i < 4; i++) {
      frame[i] = frameId.codeUnitAt(i);
    }
    // Frame size (big-endian, not syncsafe for ID3v2.3)
    frame[4] = (frameSize >> 24) & 0xFF;
    frame[5] = (frameSize >> 16) & 0xFF;
    frame[6] = (frameSize >> 8) & 0xFF;
    frame[7] = frameSize & 0xFF;
    // Flags
    frame[8] = 0;
    frame[9] = 0;
    // Encoding: UTF-8
    frame[10] = 3;
    // Text data
    for (var i = 0; i < textBytes.length; i++) {
      frame[11 + i] = textBytes[i];
    }

    return frame;
  }

  Uint8List _buildApicFrame(AlbumArtData art) {
    final mimeBytes = art.mimeType.codeUnits;
    // Frame: encoding(1) + mime(n) + null(1) + type(1) + desc null(1) + data
    final frameSize = 1 + mimeBytes.length + 1 + 1 + 1 + art.bytes.length;

    final frame = Uint8List(10 + frameSize);
    // Frame ID: APIC
    frame[0] = 0x41;
    frame[1] = 0x50;
    frame[2] = 0x49;
    frame[3] = 0x43;
    // Size
    frame[4] = (frameSize >> 24) & 0xFF;
    frame[5] = (frameSize >> 16) & 0xFF;
    frame[6] = (frameSize >> 8) & 0xFF;
    frame[7] = frameSize & 0xFF;
    // Flags
    frame[8] = 0;
    frame[9] = 0;
    // Encoding: ISO-8859-1
    frame[10] = 0;
    // MIME type
    var offset = 11;
    for (final b in mimeBytes) {
      frame[offset++] = b;
    }
    frame[offset++] = 0; // null terminator
    // Picture type
    frame[offset++] = art.type.index;
    // Description (empty, null-terminated)
    frame[offset++] = 0;
    // Image data
    for (var i = 0; i < art.bytes.length; i++) {
      frame[offset + i] = art.bytes[i];
    }

    return frame;
  }

  Uint8List _buildVorbisComment(Map<String, String> tags) {
    final output = BytesBuilder();

    // Vendor string
    const vendor = 'OpenTagEditor';
    final vendorBytes = vendor.codeUnits;
    output.add(_int32LE(vendorBytes.length));
    output.add(vendorBytes);

    // Build comment list
    final comments = <Uint8List>[];
    for (final entry in tags.entries) {
      final vorbisKey = _fieldToVorbisKey(entry.key);
      if (vorbisKey != null && entry.value.isNotEmpty) {
        final comment = '$vorbisKey=${entry.value}';
        comments.add(Uint8List.fromList(comment.codeUnits));
      }
    }

    // Comment count
    output.add(_int32LE(comments.length));

    // Comments
    for (final comment in comments) {
      output.add(_int32LE(comment.length));
      output.add(comment);
    }

    return Uint8List.fromList(output.toBytes());
  }

  List<Uint8List> _extractExistingFrames(Uint8List bytes) {
    final frames = <Uint8List>[];
    final size = _readSyncsafeInt(bytes, 6);
    var offset = 10;
    final endOffset = 10 + size;

    while (offset < endOffset - 10 && offset < bytes.length - 10) {
      final frameId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (frameId[0] == '\x00') break;

      final frameSize = (bytes[offset + 4] << 24) |
          (bytes[offset + 5] << 16) |
          (bytes[offset + 6] << 8) |
          bytes[offset + 7];

      if (frameSize <= 0 || offset + 10 + frameSize > bytes.length) break;

      frames.add(
        Uint8List.fromList(
          bytes.sublist(offset, offset + 10 + frameSize),
        ),
      );

      offset += 10 + frameSize;
    }

    return frames;
  }

  // --- Helpers ---

  void _writeSyncsafeInt(Uint8List bytes, int offset, int value) {
    bytes[offset] = (value >> 21) & 0x7F;
    bytes[offset + 1] = (value >> 14) & 0x7F;
    bytes[offset + 2] = (value >> 7) & 0x7F;
    bytes[offset + 3] = value & 0x7F;
  }

  int _readSyncsafeInt(Uint8List bytes, int offset) {
    return ((bytes[offset] & 0x7F) << 21) |
        ((bytes[offset + 1] & 0x7F) << 14) |
        ((bytes[offset + 2] & 0x7F) << 7) |
        (bytes[offset + 3] & 0x7F);
  }

  Uint8List _int32LE(int value) {
    return Uint8List.fromList([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);
  }

  String? _fieldToId3v2Frame(String field) {
    const mapping = {
      'title': 'TIT2',
      'artist': 'TPE1',
      'albumArtist': 'TPE2',
      'album': 'TALB',
      'year': 'TDRC',
      'trackNumber': 'TRCK',
      'discNumber': 'TPOS',
      'genre': 'TCON',
      'composer': 'TCOM',
      'conductor': 'TPE3',
      'lyricist': 'TEXT',
      'publisher': 'TPUB',
      'copyright': 'TCOP',
      'encodedBy': 'TENC',
      'bpm': 'TBPM',
      'compilation': 'TCMP',
    };
    return mapping[field];
  }

  String? _fieldToVorbisKey(String field) {
    const mapping = {
      'title': 'TITLE',
      'artist': 'ARTIST',
      'albumArtist': 'ALBUMARTIST',
      'album': 'ALBUM',
      'year': 'DATE',
      'trackNumber': 'TRACKNUMBER',
      'discNumber': 'DISCNUMBER',
      'genre': 'GENRE',
      'comment': 'COMMENT',
      'composer': 'COMPOSER',
      'conductor': 'CONDUCTOR',
      'lyricist': 'LYRICIST',
      'publisher': 'PUBLISHER',
      'copyright': 'COPYRIGHT',
      'encodedBy': 'ENCODEDBY',
      'bpm': 'BPM',
      'compilation': 'COMPILATION',
    };
    return mapping[field];
  }
}

class _FlacBlock {
  _FlacBlock({
    required this.type,
    required this.isLast,
    required this.data,
  });

  final int type;
  final bool isLast;
  final Uint8List data;
}
