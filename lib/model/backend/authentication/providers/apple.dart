part of 'provider.dart';

/// The Apple authentication provider.
final appleAuthenticationProvider = Provider<AppleAuthenticationProvider>(
  (ref) => AppleAuthenticationProvider._(
    ref: ref,
  ),
);

/// The Apple authentication provider.
class AppleAuthenticationProvider extends AuthenticationProvider with OAuthenticationProvider {
  /// The Apple authentication provider id.
  static const String kProviderId = 'apple';

  /// Creates a new Apple authentication provider instance.
  const AppleAuthenticationProvider._({
    required super.ref,
  }) : super(
         id: kProviderId,
       );

  @override
  User _changeId(User user, String? providerUserId) => user.updateAppleId(providerUserId);
}
