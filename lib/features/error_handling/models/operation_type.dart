/// The type of batch operation that produced an error.
enum OperationType {
  /// Tag reading operation.
  read,

  /// Tag writing operation.
  write,

  /// File rename operation.
  rename,
}
