import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart' as http;

/// Generic rate limiter that wraps an [http.Client].
///
/// Queues requests to enforce a maximum of [maxRequests] per [perDuration].
/// Automatically retries on HTTP 429 using the Retry-After header.
class RateLimiter {
  RateLimiter({
    required this.maxRequests,
    required this.perDuration,
    required http.Client innerClient,
  }) : _client = innerClient;

  /// Maximum number of requests allowed within [perDuration].
  final int maxRequests;

  /// The time window for rate limiting.
  final Duration perDuration;

  final http.Client _client;
  final Queue<DateTime> _requestTimestamps = Queue();
  final _queueController = StreamController<int>.broadcast();
  int _queueLength = 0;

  /// Number of requests currently waiting in the queue.
  int get queueLength => _queueLength;

  /// Stream that emits queue length changes for UI binding.
  Stream<int> get queueLengthStream => _queueController.stream;

  /// Maximum number of retry attempts on HTTP 429 responses.
  static const _maxRetries = 3;

  /// Sends a request, waiting if necessary to respect rate limits.
  ///
  /// Automatically retries on HTTP 429 using the Retry-After header,
  /// up to [_maxRetries] attempts.
  Future<http.Response> send(http.BaseRequest request) async {
    _queueLength++;
    _queueController.add(_queueLength);

    try {
      await _waitForSlot();

      var response = await _client.send(request).then(http.Response.fromStream);

      var retries = 0;
      while (response.statusCode == 429 && retries < _maxRetries) {
        retries++;
        final retryAfter = _parseRetryAfter(response.headers['retry-after']);
        await Future<void>.delayed(retryAfter);

        final retryRequest = _copyRequest(request);
        response = await _client
            .send(retryRequest)
            .then(http.Response.fromStream);
      }

      return response;
    } finally {
      _queueLength--;
      _queueController.add(_queueLength);
    }
  }

  /// Convenience method to send a GET request with rate limiting.
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final request = http.Request('GET', url);
    if (headers != null) request.headers.addAll(headers);
    return send(request);
  }

  /// Waits until a request slot is available within the rate limit window.
  Future<void> _waitForSlot() async {
    // Remove timestamps outside the current window
    final now = DateTime.now();
    while (_requestTimestamps.isNotEmpty &&
        now.difference(_requestTimestamps.first) > perDuration) {
      _requestTimestamps.removeFirst();
    }

    // If at capacity, wait until the oldest request expires
    if (_requestTimestamps.length >= maxRequests) {
      final oldest = _requestTimestamps.first;
      final waitTime = perDuration - now.difference(oldest);
      if (waitTime > Duration.zero) {
        await Future<void>.delayed(waitTime);
      }
      _requestTimestamps.removeFirst();
    }

    _requestTimestamps.add(DateTime.now());
  }

  /// Parses the Retry-After header value into a Duration.
  Duration _parseRetryAfter(String? value) {
    if (value == null) return const Duration(seconds: 1);
    final seconds = int.tryParse(value);
    if (seconds != null) return Duration(seconds: seconds);
    return const Duration(seconds: 1);
  }

  /// Creates a copy of a request for retry purposes.
  http.BaseRequest _copyRequest(http.BaseRequest original) {
    if (original is http.Request) {
      final copy = http.Request(original.method, original.url);
      copy.headers.addAll(original.headers);
      copy.body = original.body;
      return copy;
    }
    // Fallback: just create a new GET request
    return http.Request(original.method, original.url)
      ..headers.addAll(original.headers);
  }

  /// Disposes the rate limiter and closes the stream controller.
  void dispose() {
    _queueController.close();
  }
}
