import '../../../../core/utils/format_utils.dart';
import '../../../../shared/models/audio_file.dart';

/// Defines a column in the file list data grid.
///
/// Each column has an identifier, display label, default width, and an
/// optional [valueExtractor] function that produces the cell's text value
/// from an [AudioFile]. Columns rendered as icons (e.g. tag indicator)
/// leave [valueExtractor] null.
class ColumnDefinition {
  /// Creates a column definition.
  const ColumnDefinition({
    required this.id,
    required this.label,
    required this.defaultWidth,
    this.isFixed = false,
    this.valueExtractor,
  });

  /// Unique identifier for this column.
  final String id;

  /// Display label shown in the column header.
  final String label;

  /// Default width in logical pixels.
  final double defaultWidth;

  /// Whether the column is fixed (non-reorderable / always visible).
  final bool isFixed;

  /// Extracts the display value for a cell from an [AudioFile].
  ///
  /// May use [rootFolder] for path-relative computations.
  /// Null for columns that render non-text content (e.g. icons).
  final String Function(AudioFile file, {String? rootFolder})? valueExtractor;
}

/// The default set of columns for the file list data grid.
final List<ColumnDefinition> defaultColumns = <ColumnDefinition>[
  const ColumnDefinition(
    id: 'tagIndicator',
    label: '',
    defaultWidth: 32,
    isFixed: true,
  ),
  ColumnDefinition(
    id: 'filename',
    label: 'Filename',
    defaultWidth: 200,
    isFixed: true,
    valueExtractor: (file, {rootFolder}) => file.filename,
  ),
  ColumnDefinition(
    id: 'title',
    label: 'Title',
    defaultWidth: 150,
    valueExtractor: (file, {rootFolder}) => file.tags['title'] ?? '',
  ),
  ColumnDefinition(
    id: 'artist',
    label: 'Artist',
    defaultWidth: 150,
    valueExtractor: (file, {rootFolder}) => file.tags['artist'] ?? '',
  ),
  ColumnDefinition(
    id: 'album',
    label: 'Album',
    defaultWidth: 150,
    valueExtractor: (file, {rootFolder}) => file.tags['album'] ?? '',
  ),
  ColumnDefinition(
    id: 'year',
    label: 'Year',
    defaultWidth: 60,
    valueExtractor: (file, {rootFolder}) => file.tags['year'] ?? '',
  ),
  ColumnDefinition(
    id: 'genre',
    label: 'Genre',
    defaultWidth: 100,
    valueExtractor: (file, {rootFolder}) => file.tags['genre'] ?? '',
  ),
  ColumnDefinition(
    id: 'trackNumber',
    label: 'Track #',
    defaultWidth: 60,
    valueExtractor: (file, {rootFolder}) => file.tags['trackNumber'] ?? '',
  ),
  ColumnDefinition(
    id: 'discNumber',
    label: 'Disc #',
    defaultWidth: 60,
    valueExtractor: (file, {rootFolder}) => file.tags['discNumber'] ?? '',
  ),
  ColumnDefinition(
    id: 'bitrate',
    label: 'Bitrate',
    defaultWidth: 70,
    valueExtractor: (file, {rootFolder}) =>
        file.bitrate != null ? '${file.bitrate} kbps' : '',
  ),
  ColumnDefinition(
    id: 'duration',
    label: 'Duration',
    defaultWidth: 70,
    valueExtractor: (file, {rootFolder}) =>
        FormatUtils.formatDuration(file.duration),
  ),
  ColumnDefinition(
    id: 'albumArtist',
    label: 'Album Artist',
    defaultWidth: 150,
    valueExtractor: (file, {rootFolder}) => file.tags['albumArtist'] ?? '',
  ),
  ColumnDefinition(
    id: 'comment',
    label: 'Comment',
    defaultWidth: 150,
    valueExtractor: (file, {rootFolder}) => file.tags['comment'] ?? '',
  ),
  ColumnDefinition(
    id: 'bpm',
    label: 'BPM',
    defaultWidth: 50,
    valueExtractor: (file, {rootFolder}) => file.tags['bpm'] ?? '',
  ),
  ColumnDefinition(
    id: 'composer',
    label: 'Composer',
    defaultWidth: 150,
    valueExtractor: (file, {rootFolder}) => file.tags['composer'] ?? '',
  ),
  ColumnDefinition(
    id: 'conductor',
    label: 'Conductor',
    defaultWidth: 150,
    valueExtractor: (file, {rootFolder}) => file.tags['conductor'] ?? '',
  ),
  ColumnDefinition(
    id: 'relativePath',
    label: 'Path',
    defaultWidth: 200,
    valueExtractor: (file, {rootFolder}) =>
        FormatUtils.computeRelativePath(file.path, rootFolder ?? ''),
  ),
];
