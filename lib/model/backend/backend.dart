import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/connectivity.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/uri_builder.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The backend provider.
final backendClientProvider = AsyncNotifierProvider<BackendClient, Map<String, String>>(BackendClient.new);

/// Allows to communicate with the backend.
class BackendClient extends AsyncNotifier<Map<String, String>> {
  /// The default timeout in seconds.
  static const int _kDefaultTimeout = 10;

  /// The HTTP client instance.
  final http.Client _client = http.Client();

  @override
  FutureOr<Map<String, String>> build() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String? appClientId = await SimpleSecureStorage.read('appClientId');
    ref.onDispose(_client.close);
    return {
      'App-Version': packageInfo.version,
      'App-Client-Id': ?appClientId,
      HttpHeaders.userAgentHeader: 'OpenAuthenticator/${packageInfo.version}/${currentPlatform.name}',
    };
  }

  /// Writes the app client ID if it doesn't exist.
  Future<Map<String, String>> _writeAppClientIdIfNeeded() async {
    Map<String, String> headers = Map.of(await future);
    if (!headers.containsKey('App-Client-Id')) {
      String appClientId = currentPlatform.generateAppClientId();
      headers['App-Client-Id'] = appClientId;
      await SimpleSecureStorage.write('appClientId', appClientId);
      if (ref.mounted) {
        state = AsyncData(headers);
      }
    }
    return headers;
  }

  /// Sends an HTTP request to the backend.
  Future<Result<T>> sendHttpRequest<T extends BackendResponse>(
    BackendRequest<T> request, {
    String? backendUrl,
    Session? session,
    bool autoRefreshAccessToken = true,
  }) async {
    try {
      bool isConnected = await ref.read(connectivityStateProvider.future);
      if (!isConnected) {
        throw const SocketException('No internet connection.');
      }

      Map<String, String> headers = await _writeAppClientIdIfNeeded();
      if (request.needsAuthorization) {
        if (ref.read(sessionRefreshManagerProvider) is SessionRefreshStateInvalidSession) {
          throw InvalidSessionException();
        }
        session ??= await ref.read(storedSessionProvider.future);
        if (session == null) {
          throw NoSessionException();
        }
        headers[HttpHeaders.authorizationHeader] = 'Bearer ${session.accessToken}';
      }

      backendUrl ??= (await ref.read(backendUrlSettingsEntryProvider.future)).backendUrl;
      http.Response response = await request
          .execute(
            _client,
            UriBuilder.prefix(
              prefix: backendUrl,
              path: request.route,
            ).build(),
            headers: headers,
          )
          .timeout(const Duration(seconds: _kDefaultTimeout));
      return ResultSuccess(
        value: request.toResponse(response),
      );
    } catch (ex, stackTrace) {
      switch (ex) {
        case ExpiredSessionError():
          if (autoRefreshAccessToken) {
            Result result = await ref.read(sessionRefreshManagerProvider.notifier).refresh();
            if (result is! ResultSuccess) {
              return result.to((value) => null);
            }
            return await sendHttpRequest(
              request,
              backendUrl: backendUrl,
              autoRefreshAccessToken: false,
            );
          }
          break;
        case InvalidPayloadError():
        case InvalidTokenError():
        case InvalidSessionError():
          ref.read(sessionRefreshManagerProvider.notifier).handleBackendRequestError(ex as BackendRequestError);
          break;
      }
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Triggered when the session has been marked as invalid.
class InvalidSessionException extends LocalizableException {
  /// Creates a new invalid session exception instance.
  InvalidSessionException()
    : super(
        localizedErrorMessage: translations.error.backend.invalidSession,
      );
}
