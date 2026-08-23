/// Thrown when an online metadata service request fails (network error,
/// non-200 response, or malformed body).
///
/// This is distinct from "no results", which is a valid empty return value.
/// Throwing allows the lookup workflow to surface the failure to the user
/// instead of silently presenting it as an empty result set.
class LookupServiceException implements Exception {
  /// Creates a [LookupServiceException].
  LookupServiceException(this.message, {this.statusCode});

  /// Human-readable description of the failure.
  final String message;

  /// HTTP status code, when the failure came from a response.
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}
