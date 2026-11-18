part of '../request.dart';

/// A request that allows refresh the session.
class RefreshSessionRequest extends BackendPostRequest<RefreshSessionResponse> {
  /// The refresh token.
  final String refreshToken;

  /// Creates a new refresh session request instance.
  const RefreshSessionRequest({
    required this.refreshToken,
  }) : super(
         route: '/auth/refresh',
         needsAuthorization: false,
       );

  @override
  Object? get jsonBody => {'refreshToken': refreshToken};

  @override
  RefreshSessionResponse _toResponseIfNoError(dynamic data) => RefreshSessionResponse.fromJson(data);
}

/// A request that allows to logout the user.
class UserLogoutRequest extends BackendPostRequest<UserLogoutResponse> {
  /// The refresh token.
  final String refreshToken;

  /// Creates a new user logout request instance.
  const UserLogoutRequest({
    required this.refreshToken,
  }) : super(
         route: '/auth/logout',
         needsAuthorization: false,
       );

  @override
  Object? get jsonBody => {'refreshToken': refreshToken};

  @override
  UserLogoutResponse _toResponseIfNoError(dynamic data) => UserLogoutResponse.fromJson(data);
}

/// A request that allows to confirm an email address.
class EmailConfirmRequest extends BackendPostRequest<EmailConfirmResponse> {
  /// The email.
  final String email;

  /// The verification code.
  final String verificationCode;

  /// Creates a new email confirm request instance.
  const EmailConfirmRequest({
    required this.email,
    required this.verificationCode,
  }) : super(
         route: '/auth/provider/email/callback',
         needsAuthorization: false,
       );

  @override
  Object? get jsonBody => {
    'email': email,
    'verificationCode': verificationCode,
    'locale': translations.$meta.locale.languageCode,
  };

  @override
  EmailConfirmResponse _toResponseIfNoError(dynamic data) => EmailConfirmResponse.fromJson(data);
}

/// A request that allows to cancel an email address confirmation.
class EmailConfirmationCancelRequest extends BackendPostRequest<EmailConfirmationCancelResponse> {
  /// The email.
  final String email;

  /// The cancel code.
  final String cancelCode;

  /// Creates a new email confirmation cancel request instance.
  const EmailConfirmationCancelRequest({
    required this.email,
    required this.cancelCode,
  }) : super(
         route: '/auth/provider/email/cancel',
         needsAuthorization: false,
       );

  @override
  Object? get jsonBody => {
    'email': email,
    'cancelCode': cancelCode,
  };

  @override
  EmailConfirmationCancelResponse _toResponseIfNoError(dynamic data) => EmailConfirmationCancelResponse.fromJson(data);
}

/// A request that allows to login with a provider.
class ProviderLoginRequest extends BackendPostRequest<ProviderLoginResponse> {
  /// The authorization code.
  final String authorizationCode;

  /// The code verifier.
  final String? codeVerifier;

  /// Creates a new provider login request instance.
  ProviderLoginRequest({
    required AuthenticationProvider provider,
    required this.authorizationCode,
    this.codeVerifier,
  }) : super(
         route: '/auth/provider/${provider.id}/login',
       );

  @override
  Object? get jsonBody => {
    'authorizationCode': authorizationCode,
    if (codeVerifier != null) 'codeVerifier': codeVerifier,
  };

  @override
  ProviderLoginResponse _toResponseIfNoError(dynamic data) => ProviderLoginResponse.fromJson(data);
}

/// A request that allows to link a provider.
class ProviderLinkRequest extends BackendPostRequest<ProviderLinkResponse> {
  /// The authorization code.
  final String authorizationCode;

  /// The code verifier.
  final String? codeVerifier;

  /// Creates a new provider link request instance.
  ProviderLinkRequest({
    required AuthenticationProvider provider,
    required this.authorizationCode,
    this.codeVerifier,
  }) : super(
         route: '/auth/provider/${provider.id}/link',
         needsAuthorization: true,
       );

  @override
  Object? get jsonBody => {
    'authorizationCode': authorizationCode,
    if (codeVerifier != null) 'codeVerifier': codeVerifier,
  };

  @override
  ProviderLinkResponse _toResponseIfNoError(dynamic data) => ProviderLinkResponse.fromJson(data);
}

/// A request that allows to unlink a provider.
class ProviderUnlinkRequest extends BackendPostRequest<ProviderUnlinkResponse> {
  /// Creates a new provider unlink request instance.
  ProviderUnlinkRequest({
    required AuthenticationProvider provider,
  }) : super(
         route: '/auth/provider/${provider.id}/unlink',
         needsAuthorization: true,
       );

  @override
  ProviderUnlinkResponse _toResponseIfNoError(dynamic data) => ProviderUnlinkResponse.fromJson(data);
}
