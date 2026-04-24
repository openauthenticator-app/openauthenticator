import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';

/// Represents a backend request error.
class BackendRequestError extends LocalizableException {
  /// The route.
  final String route;

  /// The status code.
  final int statusCode;

  /// The error code.
  final String? code;

  /// The error message.
  final String? message;

  /// Creates a new backend request error instance.
  BackendRequestError._({
    String? localizedErrorMessage,
    required this.route,
    required this.statusCode,
    this.code,
    this.message,
  }) : super(
         localizedErrorMessage: localizedErrorMessage ?? translations.error.generic.noException,
       );

  /// Creates a new backend request error instance from a JSON map.
  factory BackendRequestError.fromJson({
    required String route,
    required int statusCode,
    required Map<String, dynamic> json,
  }) {
    String? code = json['data']?['errorCode'];
    String? message = json['data']?['message'];
    switch (code) {
      case ExpiredSessionError.kErrorCode:
        return ExpiredSessionError._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      case InvalidPayloadError.kErrorCode:
        return InvalidPayloadError._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      case InvalidTokenError.kErrorCode:
        return InvalidTokenError._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      case InvalidSessionError.kErrorCode:
        return InvalidSessionError._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      case ExpiredCodeError.kErrorCode:
        return ExpiredCodeError._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      case InvalidVerificationCodeError.kErrorCode:
        return InvalidVerificationCodeError._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      case InvalidAuthorizationCodeError.kErrorCode:
        return InvalidAuthorizationCodeError._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      case InvalidAppVersionError.kErrorCode:
        return InvalidAppVersionError._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      case ProviderUserAlreadyExists.kErrorCode:
        return ProviderUserAlreadyExists._(
          route: route,
          statusCode: statusCode,
          message: message,
        );
      default:
        return BackendRequestError._(
          route: route,
          statusCode: statusCode,
          code: code,
          message: json['data']['message'],
        );
    }
  }

  @override
  String toString() => [
    '$route gave returned error "$code" (HTTP $statusCode).',
    if (message != null) 'The error message is "$message".',
  ].join('\n');
}

/// Thrown when the session has expired.
class ExpiredSessionError extends BackendRequestError {
  /// The expired session error code.
  static const String kErrorCode = 'expiredSession';

  /// Creates a new expired session error instance.
  ExpiredSessionError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.expiredSession,
         code: kErrorCode,
       );
}

/// Thrown when the payload is invalid.
class InvalidPayloadError extends BackendRequestError {
  /// The invalid payload error code.
  static const String kErrorCode = 'invalidPayload';

  /// Creates a new invalid payload error instance.
  InvalidPayloadError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.invalidPayload,
         code: kErrorCode,
       );
}

/// Thrown when the token is invalid.
class InvalidTokenError extends BackendRequestError {
  /// The invalid token error code.
  static const String kErrorCode = 'invalidToken';

  /// Creates a new invalid token error instance.
  InvalidTokenError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.invalidToken,
         code: kErrorCode,
       );
}

/// Thrown when the session is invalid.
class InvalidSessionError extends BackendRequestError {
  /// The invalid session error code.
  static const String kErrorCode = 'invalidSession';

  /// Creates a new invalid session error instance.
  InvalidSessionError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.invalidSession,
         code: kErrorCode,
       );
}

/// Thrown when the verification code is expired.
class ExpiredCodeError extends BackendRequestError {
  /// The expired code error code.
  static const String kErrorCode = 'expiredCode';

  /// Creates a new expired code error instance.
  ExpiredCodeError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.expiredCode,
         code: kErrorCode,
       );
}

/// Thrown when the verification code is invalid.
class InvalidVerificationCodeError extends BackendRequestError {
  /// The invalid verification code error code.
  static const String kErrorCode = 'invalidVerificationCode';

  /// Creates a new invalid verification code error instance.
  InvalidVerificationCodeError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.invalidVerificationCode,
         code: kErrorCode,
       );
}

/// Thrown when the provider authorization code is invalid.
class InvalidAuthorizationCodeError extends BackendRequestError {
  /// The invalid authorization code error code.
  static const String kErrorCode = 'invalidAuthorizationCode';

  /// Creates a new invalid authorization code error instance.
  InvalidAuthorizationCodeError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.invalidVerificationCode,
         code: kErrorCode,
       );
}

/// Thrown when the app version is invalid.
class InvalidAppVersionError extends BackendRequestError {
  /// The invalid app version error code.
  static const String kErrorCode = 'invalidAppVersion';

  /// Creates a new invalid app version error instance.
  InvalidAppVersionError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.invalidAppVersion,
         code: kErrorCode,
       );
}

/// Thrown when the provider user already exists.
class ProviderUserAlreadyExists extends BackendRequestError {
  /// The provider user already exists error code.
  static const String kErrorCode = 'providerUserAlreadyExists';

  /// Creates a new expired session error instance.
  ProviderUserAlreadyExists._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.providerUserAlreadyExists,
         code: kErrorCode,
       );
}
