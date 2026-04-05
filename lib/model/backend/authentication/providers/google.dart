part of 'provider.dart';

/// The Google authentication provider.
final googleAuthenticationProvider = Provider<GoogleAuthenticationProvider>(
  (ref) => GoogleAuthenticationProvider._(
    ref: ref,
  ),
);

/// The Google authentication provider.
class GoogleAuthenticationProvider extends AuthenticationProvider with OAuthenticationProvider {
  /// The Google authentication provider id.
  static const String kProviderId = 'google';

  /// Creates a new Google authentication provider instance.
  const GoogleAuthenticationProvider._({
    required super.ref,
  }) : super(
         id: kProviderId,
       );

  @override
  User _changeId(User user, String? providerUserId) => user.updateGoogleId(providerUserId);
}
