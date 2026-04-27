import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/backend/synchronization/push/operation.dart';

/// Represents a backend request.
sealed class BackendRequest<T extends BackendResponse> {
  /// The route.
  final String route;

  /// Whether the request needs authorization.
  final bool needsAuthorization;

  /// Creates a new backend request instance.
  const BackendRequest({
    required this.route,
    this.needsAuthorization = false,
  });

  /// Executes the request.
  Future<http.Response> execute(http.Client client, Uri url, {Map<String, String>? headers});

  /// Converts the response to a backend response.
  T toResponse(http.Response response) {
    try {
      Map<String, dynamic> json = jsonDecode(response.body);
      if (!json.containsKey('success') || !json.containsKey('data')) {
        throw InvalidJsonResponse(
          route: route,
          statusCode: response.statusCode,
          body: response.body,
        );
      }
      if (json['success'] != true) {
        throw BackendRequestError.fromJson(
          route: route,
          statusCode: response.statusCode,
          json: json,
        );
      }
      return _toResponseIfNoError(json['data']);
    } on FormatException {
      throw InvalidJsonResponse(
        route: route,
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  /// Converts the response to a backend response.
  T _toResponseIfNoError(dynamic data);
}

/// Thrown when the response is invalid.
class InvalidJsonResponse extends LocalizableException {
  /// Creates a new invalid JSON response exception instance.
  InvalidJsonResponse({
    required String route,
    required int statusCode,
    required String body,
  }) : super(
         localizedErrorMessage: translations.error.backend.invalidJsonResponse(
           route: route,
           statusCode: statusCode,
           body: body,
         ),
       );
}

/// Represents a backend request with a body.
mixin BackendWithBodyRequest<T extends BackendResponse> on BackendRequest<T> {
  /// The body.
  Object? get jsonBody => null;

  /// The encoding.
  Encoding? get encoding => null;
}

/// Represents a backend GET request.
abstract class BackendGetRequest<T extends BackendResponse> extends BackendRequest<T> {
  /// Creates a new backend GET request instance.
  const BackendGetRequest({
    required super.route,
    super.needsAuthorization,
  });

  @override
  Future<http.Response> execute(http.Client client, Uri url, {Map<String, String>? headers}) => client.get(
    url,
    headers: headers,
  );
}

/// Represents a backend POST request.
abstract class BackendPostRequest<T extends BackendResponse> extends BackendRequest<T> with BackendWithBodyRequest<T> {
  /// Creates a new backend POST request instance.
  const BackendPostRequest({
    required super.route,
    super.needsAuthorization,
  });

  @override
  Future<http.Response> execute(http.Client client, Uri url, {Map<String, String>? headers}) => client.post(
    url,
    headers: {
      if (headers != null) ...headers,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(jsonBody),
    encoding: encoding,
  );
}

/// Represents a backend DELETE request.
abstract class BackendDeleteRequest<T extends BackendResponse> extends BackendRequest<T> with BackendWithBodyRequest<T> {
  /// Creates a new backend DELETE request instance.
  const BackendDeleteRequest({
    required super.route,
    super.needsAuthorization,
  });

  @override
  Future<http.Response> execute(http.Client client, Uri url, {Map<String, String>? headers}) => client.delete(
    url,
    headers: {
      if (headers != null) ...headers,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(jsonBody),
    encoding: encoding,
  );
}

/// A request that allows to get the user info.
class GetUserInfoRequest extends BackendGetRequest<GetUserInfoResponse> {
  /// Creates a new get user info request instance.
  const GetUserInfoRequest()
    : super(
        route: '/user',
        needsAuthorization: true,
      );

  @override
  GetUserInfoResponse _toResponseIfNoError(dynamic data) => GetUserInfoResponse.fromJson(data);
}

/// A request that allows to delete the user.
class DeleteUserRequest extends BackendDeleteRequest<DeleteUserResponse> {
  /// Creates a new delete user request instance.
  const DeleteUserRequest()
    : super(
        route: '/user',
        needsAuthorization: true,
      );

  @override
  DeleteUserResponse _toResponseIfNoError(dynamic data) => DeleteUserResponse.fromJson(data);
}

/// A request that allows to get the user totps.
class GetUserTotpsRequest extends BackendGetRequest<GetUserTotpsResponse> {
  /// Creates a new get user totps request instance.
  const GetUserTotpsRequest()
    : super(
        route: '/totps',
        needsAuthorization: true,
      );

  @override
  GetUserTotpsResponse _toResponseIfNoError(dynamic data) => GetUserTotpsResponse.fromJson(data);
}

/// A request that allows refresh the session.
class RefreshSessionRequest extends BackendPostRequest<RefreshSessionResponse> {
  /// The refresh token.
  final String refreshToken;

  /// Creates a new refresh session request instance.
  const RefreshSessionRequest({
    required this.refreshToken,
  }) : super(
         route: '/auth/refresh',
         needsAuthorization: false,
       );

  @override
  Object? get jsonBody => {'refreshToken': refreshToken};

  @override
  RefreshSessionResponse _toResponseIfNoError(dynamic data) => RefreshSessionResponse.fromJson(data);
}

/// A request that allows to logout the user.
class UserLogoutRequest extends BackendPostRequest<UserLogoutResponse> {
  /// The refresh token.
  final String refreshToken;

  /// Creates a new user logout request instance.
  const UserLogoutRequest({
    required this.refreshToken,
  }) : super(
         route: '/auth/logout',
         needsAuthorization: false,
       );

  @override
  Object? get jsonBody => {'refreshToken': refreshToken};

  @override
  UserLogoutResponse _toResponseIfNoError(dynamic data) => UserLogoutResponse.fromJson(data);
}

/// A request that allows to confirm an email address.
class EmailConfirmRequest extends BackendPostRequest<EmailConfirmResponse> {
  /// The email.
  final String email;

  /// The verification code.
  final String verificationCode;

  /// Creates a new email confirm request instance.
  const EmailConfirmRequest({
    required this.email,
    required this.verificationCode,
  }) : super(
         route: '/auth/provider/email/callback',
         needsAuthorization: false,
       );

  @override
  Object? get jsonBody => {
    'email': email,
    'verificationCode': verificationCode,
    'locale': translations.$meta.locale.languageCode,
  };

  @override
  EmailConfirmResponse _toResponseIfNoError(dynamic data) => EmailConfirmResponse.fromJson(data);
}

/// A request that allows to cancel an email address confirmation.
class EmailConfirmationCancelRequest extends BackendPostRequest<EmailConfirmationCancelResponse> {
  /// The email.
  final String email;

  /// The cancel code.
  final String cancelCode;

  /// Creates a new email confirmation cancel request instance.
  const EmailConfirmationCancelRequest({
    required this.email,
    required this.cancelCode,
  }) : super(
         route: '/auth/provider/email/cancel',
         needsAuthorization: false,
       );

  @override
  Object? get jsonBody => {
    'email': email,
    'cancelCode': cancelCode,
  };

  @override
  EmailConfirmationCancelResponse _toResponseIfNoError(dynamic data) => EmailConfirmationCancelResponse.fromJson(data);
}

/// A request that allows to login with a provider.
class ProviderLoginRequest extends BackendPostRequest<ProviderLoginResponse> {
  /// The authorization code.
  final String authorizationCode;

  /// The code verifier.
  final String? codeVerifier;

  /// Creates a new provider login request instance.
  ProviderLoginRequest({
    required AuthenticationProvider provider,
    required this.authorizationCode,
    this.codeVerifier,
  }) : super(
         route: '/auth/provider/${provider.id}/login',
       );

  @override
  Object? get jsonBody => {
    'authorizationCode': authorizationCode,
    if (codeVerifier != null) 'codeVerifier': codeVerifier,
  };

  @override
  ProviderLoginResponse _toResponseIfNoError(dynamic data) => ProviderLoginResponse.fromJson(data);
}

/// A request that allows to link a provider.
class ProviderLinkRequest extends BackendPostRequest<ProviderLinkResponse> {
  /// The authorization code.
  final String authorizationCode;

  /// The code verifier.
  final String? codeVerifier;

  /// Creates a new provider link request instance.
  ProviderLinkRequest({
    required AuthenticationProvider provider,
    required this.authorizationCode,
    this.codeVerifier,
  }) : super(
         route: '/auth/provider/${provider.id}/link',
         needsAuthorization: true,
       );

  @override
  Object? get jsonBody => {
    'authorizationCode': authorizationCode,
    if (codeVerifier != null) 'codeVerifier': codeVerifier,
  };

  @override
  ProviderLinkResponse _toResponseIfNoError(dynamic data) => ProviderLinkResponse.fromJson(data);
}

/// A request that allows to unlink a provider.
class ProviderUnlinkRequest extends BackendPostRequest<ProviderUnlinkResponse> {
  /// Creates a new provider unlink request instance.
  ProviderUnlinkRequest({
    required AuthenticationProvider provider,
  }) : super(
         route: '/auth/provider/${provider.id}/unlink',
         needsAuthorization: true,
       );

  @override
  ProviderUnlinkResponse _toResponseIfNoError(dynamic data) => ProviderUnlinkResponse.fromJson(data);
}

/// A request that allows to push operations.
class SynchronizationPushRequest extends BackendPostRequest<SynchronizationPushResponse> {
  /// The operations.
  final List<PushOperation> operations;

  /// Creates a new synchronization push request instance.
  const SynchronizationPushRequest({
    this.operations = const [],
  }) : super(
         route: '/totps/sync/push',
         needsAuthorization: true,
       );

  @override
  Object? get jsonBody => [
    for (PushOperation operation in operations) operation.toJson(httpRequest: true),
  ];

  @override
  SynchronizationPushResponse _toResponseIfNoError(dynamic data) => SynchronizationPushResponse.fromJson(data);
}

/// A request that allows to pull TOTPs.
class SynchronizationPullRequest extends BackendPostRequest<SynchronizationPullResponse> {
  /// The TOTPs that are still active.
  final Map<String, DateTime> active;

  /// The TOTPs that are still deleted.
  final Map<String, DateTime> deleted;

  /// Creates a new synchronization pull request instance.
  const SynchronizationPullRequest({
    this.active = const {},
    this.deleted = const {},
  }) : super(
         route: '/totps/sync/pull',
         needsAuthorization: true,
       );

  @override
  Object? get jsonBody {
    MapEntry<String, dynamic> convert(String key, DateTime value) => MapEntry(key, value.millisecondsSinceEpoch);
    return {
      'active': active.map(convert),
      'deleted': deleted.map(convert),
    };
  }

  @override
  SynchronizationPullResponse _toResponseIfNoError(dynamic data) => SynchronizationPullResponse.fromJson(data);
}

/// A request that allows to ping the backend.
class PingBackendRequest extends BackendGetRequest<PingBackendResponse> {
  /// Creates a new ping backend request instance.
  const PingBackendRequest()
    : super(
        route: '/ping',
      );

  @override
  PingBackendResponse _toResponseIfNoError(dynamic data) => PingBackendResponse.fromJson(data);
}
