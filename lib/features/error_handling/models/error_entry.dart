import 'operation_context.dart';
import 'operation_type.dart';

/// A single error record in the session error log.
class ErrorEntry {
  const ErrorEntry({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.operationType,
    required this.errorMessage,
    required this.timestamp,
    required this.operationContext,
  });

  /// Unique identifier for this entry (UUID).
  final String id;

  /// Full path to the file that failed.
  final String filePath;

  /// Filename only (for display).
  final String fileName;

  /// The type of operation that failed.
  final OperationType operationType;

  /// Human-readable error message.
  final String errorMessage;

  /// When the error occurred (or was last retried).
  final DateTime timestamp;

  /// Context needed to retry this operation.
  final OperationContext operationContext;

  /// Creates a copy with updated fields.
  ErrorEntry copyWith({
    String? id,
    String? filePath,
    String? fileName,
    OperationType? operationType,
    String? errorMessage,
    DateTime? timestamp,
    OperationContext? operationContext,
  }) {
    return ErrorEntry(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      operationType: operationType ?? this.operationType,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp ?? this.timestamp,
      operationContext: operationContext ?? this.operationContext,
    );
  }
}
