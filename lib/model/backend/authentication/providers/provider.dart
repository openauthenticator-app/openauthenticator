import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/native_web_auth.dart';
import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/shared_preferences_with_prefix.dart';
import 'package:open_authenticator/utils/uri_builder.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

part 'apple.dart';
part 'email.dart';
part 'github.dart';
part 'google.dart';
part 'microsoft.dart';

/// The authentication providers provider.
final authenticationProviders = Provider<List<AuthenticationProvider>>(
  (ref) => List.unmodifiable([
    EmailAuthenticationProvider._(ref: ref),
    GoogleAuthenticationProvider._(ref: ref),
    GithubAuthenticationProvider._(ref: ref),
    MicrosoftAuthenticationProvider._(ref: ref),
    AppleAuthenticationProvider._(ref: ref),
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

  /// Extracts the provider id from the given uri.
  static String? extractProviderId(Uri? uri) {
    if (uri == null || uri.scheme != 'openauthenticator' || uri.host != 'auth' || uri.pathSegments.length < 2 || uri.pathSegments.first != 'provider') {
      return null;
    }
    return uri.pathSegments[1];
  }

  /// Changes the provider id of the user.
  User _changeId(User user, String? providerUserId);

  /// Unlinks the provider.
  Future<Result> unlink() async {
    try {
      User? user = await _ref.read(userProvider.future);
      if (user == null) {
        return const ResultCancelled();
      }
      Result result = await _ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            ProviderUnlinkRequest(
              provider: this,
            ),
          );
      if (result is ResultSuccess) {
        await _ref.read(userProvider.notifier).changeUser(_changeId(user, null));
      }
      return result;
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Launches the authentication uri.
  Future<Result> _launchAuthenticationUri(UriBuilder uriBuilder) async {
    try {
      if (currentPlatform.isMobile || currentPlatform == Platform.macOS) {
        await NativeWebAuth.launch(
          url: uriBuilder.build(),
          callbackUrlScheme: 'openauthenticator',
        );
      } else {
        await launchUrl(uriBuilder.build());
      }
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      if (ex is PlatformException && ex.code == 'cancelled') {
        return const ResultCancelled();
      }
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Triggered when the redirect is received.
  Future<Result<RedirectResult>> onRedirectReceived(Uri uri) async {
    try {
      List<String> path = uri.pathSegments;
      if (path.lastOrNull != 'finish') {
        return const ResultCancelled();
      }
      String? authorizationCode = uri.queryParameters['authorizationCode'];
      if (authorizationCode == null) {
        return const ResultCancelled();
      }
      User? user = await _ref.read(userProvider.future);
      SessionRefreshState sessionRefreshState = _ref.read(sessionRefreshManagerProvider);
      if (user == null || sessionRefreshState is SessionRefreshStateInvalidSession) {
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
          return response.to((_) => null);
        }
        await _ref.read(storedSessionProvider.notifier).storeAndUse(response.value.session);
        return ResultSuccess(
          value: LogInSuccess(providerId: id),
        );
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
          return response.to((_) => null);
        }
        await _ref.read(userProvider.notifier).changeUser(_changeId(user, response.value.providerUserId));
        return ResultSuccess(
          value: LinkSuccess(
            providerId: id,
          ),
        );
      }
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Represents a possible result of [AuthenticationProvider.onRedirectReceived].
sealed class RedirectResult {
  /// The provider id.
  final String providerId;

  /// Creates a new redirect result instance.
  const RedirectResult({
    required this.providerId,
  });

  /// The localized message to display.
  String get localizedMessage;
}

/// Triggered when a user has successfully logged in.
class LogInSuccess extends RedirectResult {
  /// Creates a new log in success instance.
  const LogInSuccess({
    required super.providerId,
  });

  @override
  String get localizedMessage => translations.authentication.logIn.success;
}

/// Triggered when a user has successfully linked its account to the provider.
class LinkSuccess extends RedirectResult {
  /// Creates a new link success instance.
  const LinkSuccess({
    required super.providerId,
  });

  @override
  String get localizedMessage => translations.authentication.link.linkSuccess;
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
    UriBuilder uriBuilder = UriBuilder.prefix(
      prefix: backendUrl,
      path: '/auth/provider/$id/redirect',
      queryParameters: {
        'locale': translations.$meta.locale.languageCode,
      },
    );
    if (link) {
      User? user = await _ref.read(userProvider.future);
      uriBuilder.appendQueryParameter('userId', user!.id);
      uriBuilder.appendQueryParameter('mode', 'link');
    } else {
      uriBuilder.appendQueryParameter('mode', 'login');
    }
    uriBuilder.appendQueryParameter('timestamp', DateTime.now().millisecondsSinceEpoch.toString());
    return await _launchAuthenticationUri(uriBuilder);
  }
}

/// Allows to find a provider in an authentication providers list.
extension FindProvider on List<AuthenticationProvider> {
  /// Finds the provider with the given id.
  AuthenticationProvider? findProvider(String id) => firstWhereOrNull((provider) => provider.id == id);

  /// Finds the email provider.
  EmailAuthenticationProvider get email => findProvider(EmailAuthenticationProvider.kProviderId)! as EmailAuthenticationProvider;
}
