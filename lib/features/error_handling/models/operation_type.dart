/// The type of batch operation that produced an error.
enum OperationType {
  /// Tag reading operation.
  read,

  /// Tag writing operation.
  write,

  /// File rename operation.
  rename,

  /// Online metadata lookup failure (informational, not auto-retryable:
  /// replaying a web search is neither deterministic nor rate-limit-safe).
  onlineLookup,
}
