/// A general-purpose cancellation token for long-running asynchronous tasks.
class CancellationToken {
  bool _isCancelled = false;

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation.
  void cancel() {
    _isCancelled = true;
  }
}
