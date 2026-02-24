part of 'provider.dart';

/// The Github authentication provider.
final githubAuthenticationProvider = Provider<GithubAuthenticationProvider>(
  (ref) => GithubAuthenticationProvider._(
    ref: ref,
  ),
);

/// The Github authentication provider.
class GithubAuthenticationProvider extends AuthenticationProvider with OAuthenticationProvider {
  /// The Github authentication provider id.
  static const String kProviderId = 'github';

  /// Creates a new Github authentication provider instance.
  const GithubAuthenticationProvider._({
    required super.ref,
  }) : super(
         id: kProviderId,
       );

  @override
  User _changeId(User user, String providerUserId) => user.copyWith(githubId: providerUserId);
}
