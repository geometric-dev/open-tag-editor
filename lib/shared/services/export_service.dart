import 'dart:typed_data';

import '../models/audio_file.dart';
import 'xlsx/xlsx_writer.dart';

/// One row to export: a header label plus its cell value.
typedef ExportColumn = ({String header, String Function(AudioFile) value});

/// Exports the file list to CSV, HTML, or XLSX, mirroring Tag&Rename's
/// "Export files information" wizard.
class ExportService {
  ExportService._();

  /// Builds default export columns from [visibleColumnIds] so exports match
  /// what the user sees in the grid.
  static List<ExportColumn> columnsFor(Set<String> visibleColumnIds) {
    final all = <String, String Function(AudioFile)>{
      'filename': (f) => f.filename,
      'title': (f) => f.tags['title'] ?? '',
      'artist': (f) => f.tags['artist'] ?? '',
      'albumArtist': (f) => f.tags['albumArtist'] ?? '',
      'album': (f) => f.tags['album'] ?? '',
      'year': (f) => f.tags['year'] ?? '',
      'genre': (f) => f.tags['genre'] ?? '',
      'trackNumber': (f) => f.tags['trackNumber'] ?? '',
      'trackTotal': (f) => f.tags['trackTotal'] ?? '',
      'discNumber': (f) => f.tags['discNumber'] ?? '',
      'discTotal': (f) => f.tags['discTotal'] ?? '',
      'comment': (f) => f.tags['comment'] ?? '',
      'composer': (f) => f.tags['composer'] ?? '',
      'conductor': (f) => f.tags['conductor'] ?? '',
      'bpm': (f) => f.tags['bpm'] ?? '',
      'rating': (f) => f.tags['rating'] ?? '',
      'mood': (f) => f.tags['mood'] ?? '',
      'grouping': (f) => f.tags['grouping'] ?? '',
      'subtitle': (f) => f.tags['subtitle'] ?? '',
      'language': (f) => f.tags['language'] ?? '',
      'originalArtist': (f) => f.tags['originalArtist'] ?? '',
      'remixer': (f) => f.tags['remixer'] ?? '',
      'label': (f) => f.tags['label'] ?? '',
      'catalogNumber': (f) => f.tags['catalogNumber'] ?? '',
      'isrc': (f) => f.tags['isrc'] ?? '',
      'url': (f) => f.tags['url'] ?? '',
      'lyrics': (f) => f.tags['lyrics'] ?? '',
      'bitrate': (f) => f.bitrate?.toString() ?? '',
      'duration': (f) =>
          f.duration != null ? f.duration!.toStringAsFixed(0) : '',
      'path': (f) => f.path,
    };
    return [
      for (final id in visibleColumnIds)
        if (all[id] != null && id != 'tagIndicator')
          (header: _headerLabel(id), value: all[id]!),
    ];
  }

  static String _headerLabel(String columnId) {
    switch (columnId) {
      case 'filename':
        return 'Filename';
      case 'trackNumber':
        return 'Track #';
      case 'discNumber':
        return 'Disc #';
      case 'albumArtist':
        return 'Album Artist';
      case 'originalArtist':
        return 'Original Artist';
      case 'catalogNumber':
        return 'Catalog #';
      case 'isrc':
        return 'ISRC';
      case 'url':
        return 'URL';
      default:
        return columnId[0].toUpperCase() + columnId.substring(1);
    }
  }

  /// Serializes [files] as RFC-4180 CSV (comma-delimited, quoted fields
  /// containing comma/quote/newline; quotes doubled). Emits a UTF-8 BOM so
  /// Excel detects encoding when opened by double-click.
  static String toCsv(
    List<AudioFile> files,
    List<ExportColumn> columns, {
    bool includeBom = true,
  }) {
    final buffer = StringBuffer();
    if (includeBom) buffer.write('\uFEFF');
    buffer.writeln(columns.map((c) => _csvField(c.header)).join(','));
    for (final file in files) {
      buffer.writeln(columns.map((c) => _csvField(c.value(file))).join(','));
    }
    return buffer.toString();
  }

  static String _csvField(String raw) {
    if (raw.contains(',') || raw.contains('"') || raw.contains('\n')) {
      return '"${raw.replaceAll('"', '""')}"';
    }
    return raw;
  }

  /// Serializes [files] as a standalone HTML table with minimal styling.
  static String toHtml(List<AudioFile> files, List<ExportColumn> columns) {
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html><head><meta charset="utf-8">')
      ..writeln('<title>Open Tag Editor export</title>')
      ..writeln(
        '<style>body{font-family:Segoe UI,sans-serif;font-size:13px}'
        'table{border-collapse:collapse}td,th{border:1px solid #bbb;'
        'padding:4px 8px}th{background:#eee;text-align:left}</style>',
      )
      ..writeln('</head><body>')
      ..writeln('<table>');
    buffer.write('<tr>');
    for (final c in columns) {
      buffer.write('<th>${_escape(c.header)}</th>');
    }
    buffer.writeln('</tr>');
    for (final file in files) {
      buffer.write('<tr>');
      for (final c in columns) {
        buffer.write('<td>${_escape(c.value(file))}</td>');
      }
      buffer.writeln('</tr>');
    }
    buffer
      ..writeln('</table>')
      ..writeln('</body></html>');
    return buffer.toString();
  }

  /// Serializes [files] into a true .xlsx workbook (single sheet,
  /// inline-string cells; numeric-looking values become number cells).
  static Uint8List toXlsx(List<AudioFile> files, List<ExportColumn> columns) {
    final writer = XlsxWriter()..addRow([for (final c in columns) c.header]);
    for (final file in files) {
      writer.addRow([for (final c in columns) c.value(file)]);
    }
    return writer.build();
  }

  /// Serializes based on output extension: .xlsx, .html/.htm, else CSV.
  static Object serializeFor(
    String outputPath,
    List<AudioFile> files,
    List<ExportColumn> columns,
  ) {
    final lower = outputPath.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return toHtml(files, columns);
    }
    if (lower.endsWith('.xlsx')) {
      return toXlsx(files, columns);
    }
    return toCsv(files, columns);
  }

  static String _escape(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
