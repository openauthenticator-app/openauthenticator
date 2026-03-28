/// Represents a backend request error.
class BackendRequestError implements Exception {
  /// The expired session error code.
  static const String kExpiredSessionError = 'expiredSession';

  /// The invalid payload error code.
  static const String kInvalidPayloadError = 'invalidPayload';

  /// The invalid token error code.
  static const String kInvalidTokenError = 'invalidToken';

  /// The invalid session error code.
  static const String kInvalidSessionError = 'invalidSession';

  /// The invalid verification code error code.
  static const String kInvalidVerificationCodeError = 'invalidVerificationCode';

  /// The route.
  final String route;

  /// The status code.
  final int statusCode;

  /// The error code.
  final String? errorCode;

  /// The error message.
  final String? message;

  /// Creates a new backend request error instance.
  const BackendRequestError({
    required this.route,
    required this.statusCode,
    this.errorCode,
    this.message,
  });

  /// Creates a new backend request error instance from a JSON map.
  BackendRequestError.fromJson(String route, Map<String, dynamic> json)
    : this(
        route: route,
        statusCode: json['statusCode'],
        errorCode: json['errorCode'],
        message: json['message'],
      );

  @override
  String toString() => [
    '$route gave returned error "$errorCode" (HTTP $statusCode).',
    if (message != null) 'The error message is "$message".',
  ].join('\n');
}
