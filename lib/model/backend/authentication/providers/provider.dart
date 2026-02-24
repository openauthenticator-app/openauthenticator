import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/shared_preferences_with_prefix.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

part 'apple.dart';
part 'email.dart';
part 'github.dart';
part 'google.dart';
part 'microsoft.dart';

/// The authentication provider provider.
final authenticationProvider = Provider.family<AuthenticationProvider?, String>(
  (ref, id) => ref.watch(
    authenticationProviders.select(
      (providers) => providers.firstWhereOrNull(
        (provider) => provider.id == id,
      ),
    ),
  ),
);

/// The authentication providers provider.
final authenticationProviders = Provider<List<AuthenticationProvider>>(
  (ref) => List.unmodifiable([
    ref.watch(emailAuthenticationProvider),
    ref.watch(googleAuthenticationProvider),
    ref.watch(githubAuthenticationProvider),
    ref.watch(microsoftAuthenticationProvider),
    ref.watch(appleAuthenticationProvider),
  ]),
);

/// The user authentication providers provider.
final userAuthenticationProviders = Provider<List<AuthenticationProvider>>((ref) {
  User? user = ref.watch(userProvider).value;
  if (user == null) {
    return [];
  }
  List<AuthenticationProvider> providers = ref.watch(authenticationProviders);
  return List.unmodifiable([
    for (AuthenticationProvider provider in providers)
      if (user.hasAuthenticationProvider(provider.id)) provider,
  ]);
});

/// Represents an authentication provider.
sealed class AuthenticationProvider {
  /// The authentication provider id.
  final String id;

  /// The Riverpod ref instance.
  final Ref _ref;

  /// Creates a new authentication provider instance.
  const AuthenticationProvider({
    required this.id,
    required Ref ref,
  }) : _ref = ref;

  /// Changes the provider id of the user.
  User _changeId(User user, String providerUserId);

  /// Unlinks the provider.
  Future<Result> unlink() async {
    try {
      User? user = await _ref.read(userProvider.future);
      if (user == null) {
        return const ResultCancelled();
      }
      return await _ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            ProviderUnlinkRequest(
              provider: this,
            ),
          );
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Triggered when the redirect is received.
  Future<Result> onRedirectReceived(Uri uri) async {
    try {
      List<String> path = uri.pathSegments;
      if (path.lastOrNull != 'code') {
        return const ResultCancelled();
      }
      String? authorizationCode = uri.queryParameters['authorizationCode'];
      if (authorizationCode == null) {
        return const ResultCancelled();
      }
      User? user = await _ref.read(userProvider.future);
      SessionRefreshState sessionRefreshState = _ref.read(sessionRefreshManagerProvider);
      if (user == null || sessionRefreshState == .invalidSession) {
        Result<ProviderLoginResponse> response = await _ref
            .read(backendClientProvider.notifier)
            .sendHttpRequest(
              ProviderLoginRequest(
                provider: this,
                authorizationCode: authorizationCode,
                codeVerifier: uri.queryParameters['codeVerifier'],
              ),
            );
        if (response is! ResultSuccess<ProviderLoginResponse>) {
          return response;
        }
        await _ref.read(storedSessionProvider.notifier).storeAndUse(response.value.session);
      } else {
        Result<ProviderLinkResponse> response = await _ref
            .read(backendClientProvider.notifier)
            .sendHttpRequest(
              ProviderLinkRequest(
                provider: this,
                authorizationCode: authorizationCode,
                codeVerifier: uri.queryParameters['codeVerifier'],
              ),
            );
        if (response is! ResultSuccess<ProviderLinkResponse>) {
          return response;
        }
        await _ref.read(userProvider.notifier).changeUser(_changeId(user, response.value.providerUserId));
      }
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }
}

/// An OAuthentication provider.
mixin OAuthenticationProvider on AuthenticationProvider {
  /// Requests to sign in.
  Future<Result> requestSignIn() => _requestLogin(link: false);

  /// Requests to link.
  Future<Result> requestLinking() => _requestLogin(link: true);

  /// Requests a login for either signing in or linking.
  Future<Result> _requestLogin({bool link = false}) async {
    String backendUrl = await _ref.read(backendUrlSettingsEntryProvider.future);
    String uriPrefix = '$backendUrl/auth/provider/$id/redirect';
    Uri uri;
    if (link) {
      User? user = await _ref.read(userProvider.future);
      uri = Uri.parse('$uriPrefix?mode=link&userId=${user!.id}');
    } else {
      uri = Uri.parse('$uriPrefix?mode=login');
    }
    await launchUrl(uri);
    return const ResultSuccess();
  }
}
