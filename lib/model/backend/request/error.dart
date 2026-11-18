import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/json.dart';
import 'package:open_authenticator/utils/result/reporter.dart';

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
    required JsonMap json,
  }) {
    final Object? data = json['data'];
    final String? code = data is Map ? data['errorCode']?.toString() : null;
    final String? message = data is Map ? data['message']?.toString() : null;
    final _BackendRequestErrorConstructor? constructor = _kErrors[code];
    return constructor == null
        ? BackendRequestError._(
            route: route,
            statusCode: statusCode,
            code: code,
            message: message,
          )
        : constructor(
            route: route,
            statusCode: statusCode,
            message: message,
          );
  }

  /// Maps error codes to their corresponding error class.
  static const Map<String, _BackendRequestErrorConstructor> _kErrors = {
    ExpiredSessionError.kErrorCode: ExpiredSessionError._,
    InvalidPayloadError.kErrorCode: InvalidPayloadError._,
    InvalidTokenError.kErrorCode: InvalidTokenError._,
    InvalidSessionError.kErrorCode: InvalidSessionError._,
    ExpiredCodeError.kErrorCode: ExpiredCodeError._,
    _InvalidVerificationCodeError.kErrorCode: _InvalidVerificationCodeError._,
    _InvalidAuthorizationCodeError.kErrorCode: _InvalidAuthorizationCodeError._,
    InvalidAppVersionError.kErrorCode: InvalidAppVersionError._,
    _ProviderUserAlreadyExistsError.kErrorCode: _ProviderUserAlreadyExistsError._,
  };

  @override
  String toString() => [
    '$route gave returned error "$code" (HTTP $statusCode).',
    if (message != null) 'The error message is "$message".',
  ].join('\n');
}

/// A constructor of a [BackendRequestError] subclass.
typedef _BackendRequestErrorConstructor = BackendRequestError Function({required String route, required int statusCode, String? message});

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
class ExpiredCodeError extends BackendRequestError with UserError {
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
class _InvalidVerificationCodeError extends BackendRequestError with UserError {
  /// The invalid verification code error code.
  static const String kErrorCode = 'invalidVerificationCode';

  /// Creates a new invalid verification code error instance.
  _InvalidVerificationCodeError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.invalidVerificationCode,
         code: kErrorCode,
       );
}

/// Thrown when the provider authorization code is invalid.
class _InvalidAuthorizationCodeError extends BackendRequestError with UserError {
  /// The invalid authorization code error code.
  static const String kErrorCode = 'invalidAuthorizationCode';

  /// Creates a new invalid authorization code error instance.
  _InvalidAuthorizationCodeError._({
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
class _ProviderUserAlreadyExistsError extends BackendRequestError with UserError {
  /// The provider user already exists error code.
  static const String kErrorCode = 'providerUserAlreadyExists';

  /// Creates a new expired session error instance.
  _ProviderUserAlreadyExistsError._({
    required super.route,
    required super.statusCode,
    super.message,
  }) : super._(
         localizedErrorMessage: translations.error.backend.providerUserAlreadyExists,
         code: kErrorCode,
       );
}
