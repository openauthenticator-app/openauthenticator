/// Handles `openauthenticator://` links.
extension type OpenAuthenticatorAppLink(Uri uri) implements Uri {
  /// The scheme.
  static const String _kScheme = 'openauthenticator';

  /// Returns whether the given [uri] is a valid app link.
  bool get isValid => uri.isScheme(_kScheme);
}
