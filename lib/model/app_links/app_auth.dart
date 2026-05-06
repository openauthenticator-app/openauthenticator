import 'package:open_authenticator/model/app_links/openauthenticator.dart';

/// Handles `openauthenticator://auth/` links.
extension type AppAuthLink(OpenAuthenticatorAppLink uri) implements OpenAuthenticatorAppLink {
  /// The scheme.
  static const String _kScheme = 'openauthenticator';

  /// The host.
  static const String _kHost = 'auth';

  /// The first path segment.
  static const String _kFirstPathSegment = 'provider';

  /// Returns whether the given [uri] is a valid app auth link.
  bool get isValid => uri.isScheme(_kScheme) && uri.host == _kHost && uri.pathSegments.length >= 2 && uri.pathSegments.firstOrNull == _kFirstPathSegment;

  /// Returns the provider id.
  String get providerId => uri.pathSegments[1];
}

/// Handles `openauthenticator://auth/.../finish` links.
extension type FinishAuthAppLink(AppAuthLink uri) implements AppAuthLink {
  /// The authorization code query parameter.
  static const String _kAuthorizationCodeQueryParameter = 'authorizationCode';

  /// The code verifier query parameter.
  static const String _kCodeVerifierQueryParameter = 'codeVerifier';

  /// The last path segment.
  static const String _kLastPathSegment = 'finish';

  /// Returns whether the given [uri] is a valid finish auth app link.
  bool get isValid => (this as AppAuthLink).isValid && uri.pathSegments.lastOrNull == _kLastPathSegment && uri.queryParameters[_kAuthorizationCodeQueryParameter] != null;

  /// Returns the authorization code.
  String get authorizationCode => uri.queryParameters[_kAuthorizationCodeQueryParameter]!;

  /// Returns the code verifier.
  String? get codeVerifier => uri.queryParameters[_kCodeVerifierQueryParameter];
}

/// Handles `openauthenticator://auth/provider/email/sent` links.
extension type EmailSentAppLink(AppAuthLink uri) implements AppAuthLink {
  /// The path.
  static const String _kPath = '/provider/email/sent';

  /// The email query parameter.
  static const String _kEmailQueryParameter = 'email';

  /// The cancel code query parameter.
  static const String _kCancelCodeQueryParameter = 'cancelCode';

  /// The previously query parameter.
  static const String _kPreviouslyQueryParameter = 'previously';

  /// Returns whether the given [uri] is a email sent app link.
  bool get isValid => (this as AppAuthLink).isValid && uri.path == _kPath && uri.queryParameters[_kEmailQueryParameter] != null;

  /// Returns the email.
  String get email => uri.queryParameters[_kEmailQueryParameter]!;

  /// Returns the cancel code.
  String? get cancelCode => uri.queryParameters[_kCancelCodeQueryParameter];

  /// Returns whether the email has already been sent.
  bool get previously => uri.queryParameters[_kPreviouslyQueryParameter]?.toLowerCase() == 'true';
}
