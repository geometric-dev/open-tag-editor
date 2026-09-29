import 'dart:typed_data';

import 'zip_writer.dart';

export 'zip_writer.dart' show ZipWriter, crc32;

/// Minimal SpreadsheetML (.xlsx) writer.
///
/// Emits a single worksheet with inline-string cells (no shared strings),
/// which Excel/LibreOffice/Numbers open natively. Numbers are written as
/// numeric cells when the value parses as a double, everything else as
/// text. Stored-ZIP only — no compression, no dependencies.
class XlsxWriter {
  XlsxWriter();

  final List<List<String?>> _rows = [];

  /// Appends a row of cell values. `null` writes an empty cell.
  void addRow(List<String?> values) => _rows.add(values);

  /// Builds the .xlsx bytes.
  Uint8List build() {
    final zip = ZipWriter()
      ..addText('[Content_Types].xml', _contentTypes)
      ..addText('_rels/.rels', _rootRels)
      ..addText('xl/workbook.xml', _workbook)
      ..addText('xl/_rels/workbook.xml.rels', _workbookRels)
      ..addText('xl/worksheets/sheet1.xml', _sheetXml());

    return zip.build();
  }

  String _sheetXml() {
    final buffer = StringBuffer()
      ..write(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
        '2006/main"><sheetData>',
      );

    for (var r = 0; r < _rows.length; r++) {
      buffer.write('<row r="${r + 1}">');
      final row = _rows[r];
      for (var c = 0; c < row.length; c++) {
        final value = row[c];
        if (value == null || value.isEmpty) continue;
        final ref = '${_columnLetter(c)}${r + 1}';
        final numeric = double.tryParse(value);
        if (numeric != null && !value.contains(RegExp(r'^0\d'))) {
          // Numeric cell; leading-zero strings (e.g. "007") stay text.
          buffer.write('<c r="$ref"><v>$value</v></c>');
        } else {
          buffer.write(
            '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
            '${_escape(value)}'
            '</t></is></c>',
          );
        }
      }
      buffer.write('</row>');
    }

    buffer.write('</sheetData></worksheet>');
    return buffer.toString();
  }

  static String get _contentTypes =>
      '<?xml version="1.0" encoding="UTF-8" '
      'standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
      'content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-'
      'package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType='
      '"application/vnd.openxmlformats-officedocument.spreadsheetml.'
      'worksheet+xml"/>'
      '</Types>';

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" '
      'standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/officeDocument" '
      'Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbook =
      '<?xml version="1.0" encoding="UTF-8" '
      'standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/'
      'main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/'
      'relationships">'
      '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  static const _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" '
      'standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet1.xml"/>'
      '</Relationships>';

  /// 0-based column index to spreadsheet letters: A..Z, AA..ZZ...
  static String _columnLetter(int index) {
    var i = index;
    var out = '';
    do {
      out = String.fromCharCode(0x41 + (i % 26)) + out;
      i = i ~/ 26 - 1;
    } while (i >= 0);
    return out;
  }

  static String _escape(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
