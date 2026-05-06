import 'package:open_authenticator/model/app_links/openauthenticator.dart';

/// Handles `openauthenticator://purchases/` links.
extension type AppPurchasesLink(OpenAuthenticatorAppLink uri) implements OpenAuthenticatorAppLink {
  /// The scheme.
  static const String _kScheme = 'openauthenticator';

  /// The host.
  static const String _kHost = 'purchases';

  /// Returns whether the given [uri] is a valid purchases app link.
  bool get isValid => uri.isScheme(_kScheme) && uri.host == _kHost;
}

/// Handles `openauthenticator://purchases/success` links.
extension type AppPurchasesSuccessLink(AppPurchasesLink uri) implements AppPurchasesLink {
  /// The path.
  static const String _kPath = '/success';

  /// Returns whether the given [uri] is a valid purchases success app link.
  bool get isValid => (this as AppPurchasesLink).isValid && uri.path == _kPath;
}
