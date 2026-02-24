import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/connectivity.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The backend provider.
final backendClientProvider = AsyncNotifierProvider<BackendClient, Map<String, String>>(BackendClient.new);

/// Allows to communicate with the backend.
class BackendClient extends AsyncNotifier<Map<String, String>> {
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
    };
  }

  /// Writes the app client ID if it doesn't exist.
  Future<Map<String, String>> _writeAppClientIdIfNeeded() async {
    Map<String, String> headers = Map.of(await future);
    if (!headers.containsKey('App-Client-Id')) {
      String appClientId = currentPlatform.generateAppClientId();
      headers['App-Client-Id'] = appClientId;
      await SimpleSecureStorage.write('appClientId', appClientId);
      state = AsyncData(headers);
    }
    return headers;
  }

  /// Sends an HTTP request to the backend.
  Future<Result<T>> sendHttpRequest<T extends BackendResponse>(
    BackendRequest<T> request, {
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
        if (ref.read(sessionRefreshManagerProvider) == .invalidSession) {
          throw const InvalidSessionException();
        }
        session ??= await ref.read(storedSessionProvider.future);
        if (session == null) {
          throw const NoSessionException();
        }
        headers[HttpHeaders.authorizationHeader] = 'Bearer ${session.accessToken}';
      }

      String backendUrl = await ref.read(backendUrlSettingsEntryProvider.future);
      http.Response response = await request.execute(
        _client,
        Uri.parse(backendUrl + request.route),
        headers: headers,
      );
      return ResultSuccess(
        value: request.toResponse(response),
      );
    } catch (ex, stackTrace) {
      if (autoRefreshAccessToken && _hasSessionExpired(ex)) {
        Result result = await ref.read(sessionRefreshManagerProvider.notifier).refresh();
        if (result is! ResultSuccess) {
          return result.to((value) => null);
        }
        return await sendHttpRequest(
          request,
          autoRefreshAccessToken: false,
        );
      }
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Allows to check if the session is valid using the given error.
  bool _hasSessionExpired(Object? error) => error is BackendRequestError && error.errorCode == BackendRequestError.kExpiredSessionError;
}

/// Triggered when the session has been marked as invalid.
class InvalidSessionException implements Exception {
  /// Creates a new invalid session exception instance.
  const InvalidSessionException();

  @override
  String toString() => 'The session is marked as invalid';
}
