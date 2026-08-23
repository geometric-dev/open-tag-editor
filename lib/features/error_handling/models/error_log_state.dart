import 'error_entry.dart';

/// Immutable state of the error log.
class ErrorLogState {
  const ErrorLogState({this.entries = const []});

  /// The list of error entries in the log.
  final List<ErrorEntry> entries;

  /// The number of entries in the log.
  int get count => entries.length;

  /// Whether the log contains no entries.
  bool get isEmpty => entries.isEmpty;

  /// Whether the log contains one or more entries.
  bool get isNotEmpty => entries.isNotEmpty;
}
