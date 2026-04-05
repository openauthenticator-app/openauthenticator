part of 'provider.dart';

/// The Microsoft authentication provider.
final microsoftAuthenticationProvider = Provider<MicrosoftAuthenticationProvider>(
  (ref) => MicrosoftAuthenticationProvider._(
    ref: ref,
  ),
);

/// The Microsoft authentication provider.
class MicrosoftAuthenticationProvider extends AuthenticationProvider with OAuthenticationProvider {
  /// The Microsoft authentication provider id.
  static const String kProviderId = 'microsoft';

  /// Creates a new Microsoft authentication provider instance.
  const MicrosoftAuthenticationProvider._({
    required super.ref,
  }) : super(
         id: kProviderId,
       );

  @override
  User _changeId(User user, String? providerUserId) => user.updateMicrosoftId(providerUserId);
}
