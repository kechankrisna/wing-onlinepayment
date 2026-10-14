/// What went wrong in a [WingException].
enum WingErrorType {
  /// Wing could not be reached (DNS, refused connection, offline, ...)
  connection,

  /// connecting, sending or receiving took longer than the configured timeout
  timeout,

  /// the call was cancelled with its `CancelToken`
  cancelled,

  /// Wing's TLS certificate was rejected
  badCertificate,

  /// Wing answered without an `errorCode` (e.g. an HTML page)
  unexpectedResponse,

  /// the payload could not be encrypted, e.g. a password shorter than 16
  /// bytes
  encryption,

  /// callback `contents` could not be decrypted with the password, or is
  /// not the JSON object Wing sends
  invalidCallback,

  /// any other failure; see [WingException.cause]
  unknown,
}

/// Thrown when Wing could not be reached or did not answer with an
/// `errorCode`, and for invalid local input such as a short password.
///
/// Wing business errors (invalid API key, transaction not found, ...) are
/// not thrown: they are returned in the response `status`.
class WingException implements Exception {
  /// what went wrong
  final WingErrorType type;

  /// human readable description, for logs
  final String message;

  /// HTTP status code, when a response was received
  final int? statusCode;

  /// the underlying error, e.g. a `DioException`
  final Object? cause;

  /// Creates an exception of [type] described by [message].
  const WingException(this.type, this.message, {this.statusCode, this.cause});

  /// whether retrying the same call later may succeed
  bool get isRetryable =>
      type == WingErrorType.connection ||
      type == WingErrorType.timeout ||
      (type == WingErrorType.unexpectedResponse && (statusCode ?? 0) >= 500);

  @override
  String toString() => statusCode == null
      ? 'WingException(${type.name}): $message'
      : 'WingException(${type.name}): $message (HTTP $statusCode)';
}
