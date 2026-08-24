import 'dart:convert';
import 'dart:typed_data';

/// Minimal ZIP archive writer using the STORED (no compression) method.
///
/// Sufficient for container formats whose readers accept uncompressed
/// entries — notably .xlsx (OOXML). Pure Dart, no dependencies.
class ZipWriter {
  ZipWriter() : _entries = <_ZipEntry>[];

  final List<_ZipEntry> _entries;

  /// Adds a file entry. [data] is stored uncompressed.
  void addFile(String name, Uint8List data) {
    _entries.add(
      _ZipEntry(name: name, data: data, crc32: crc32(data)),
    );
  }

  void addText(String name, String text) {
    addFile(name, utf8.encode(text));
  }

  bool get isEmpty => _entries.isEmpty;

  /// Serializes the archive: local headers + data, central directory,
  /// end-of-central-directory record.
  Uint8List build() {
    final out = BytesBuilder();

    final offsets = <int>[];
    for (final entry in _entries) {
      offsets.add(out.length);
      final nameBytes = utf8.encode(entry.name);

      out.add(_u32(0x04034b50)); // local file header signature
      out.add(_u16(20)); // version needed
      out.add(_u16(0x0800)); // flags: UTF-8 names
      out.add(_u16(0)); // method: stored
      out.add(_u16(0)); // mod time
      out.add(_u16(0)); // mod date (1980-01-01; xlsx ignores it)
      out.add(_u32(entry.crc32));
      out.add(_u32(entry.data.length)); // compressed
      out.add(_u32(entry.data.length)); // uncompressed
      out.add(_u16(nameBytes.length));
      out.add(_u16(0)); // extra length
      out.add(nameBytes);
      out.add(entry.data);
    }

    final centralStart = out.length;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      final nameBytes = utf8.encode(entry.name);

      out.add(_u32(0x02014b50)); // central directory signature
      out.add(_u16(20)); // version made by
      out.add(_u16(20)); // version needed
      out.add(_u16(0x0800)); // UTF-8 flag
      out.add(_u16(0)); // method stored
      out.add(_u16(0)); // time
      out.add(_u16(0)); // date
      out.add(_u32(entry.crc32));
      out.add(_u32(entry.data.length));
      out.add(_u32(entry.data.length));
      out.add(_u16(nameBytes.length));
      out.add(_u16(0)); // extra
      out.add(_u16(0)); // comment
      out.add(_u16(0)); // disk number
      out.add(_u16(0)); // internal attrs
      out.add(_u32(0)); // external attrs
      out.add(_u32(offsets[i]));
      out.add(nameBytes);
    }
    final centralSize = out.length - centralStart;

    out.add(_u32(0x06054b50)); // EOCD
    out.add(_u16(0)); // this disk
    out.add(_u16(0)); // cd start disk
    out.add(_u16(_entries.length));
    out.add(_u16(_entries.length));
    out.add(_u32(centralSize));
    out.add(_u32(centralStart));
    out.add(_u16(0)); // comment length

    return out.toBytes();
  }
}

class _ZipEntry {
  const _ZipEntry({
    required this.name,
    required this.data,
    required this.crc32,
  });

  final String name;
  final Uint8List data;
  final int crc32;
}

Uint8List _u16(int v) => Uint8List.fromList([v & 0xFF, (v >> 8) & 0xFF]);

Uint8List _u32(int v) => Uint8List.fromList([
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);

/// CRC-32 (IEEE 802.3), table-driven.
int crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      final mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xEDB88320 & mask);
    }
  }
  return (~crc) & 0xFFFFFFFF;
}
