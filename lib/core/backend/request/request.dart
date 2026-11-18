import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:open_authenticator/core/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/core/backend/request/error.dart';
import 'package:open_authenticator/core/backend/request/response.dart';
import 'package:open_authenticator/core/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/json.dart';

part 'requests/authentication.dart';
part 'requests/backend.dart';
part 'requests/synchronization.dart';
part 'requests/user.dart';

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
      final JsonMap json = decodeJsonMap(response.body);
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
      ...?headers,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(jsonBody),
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
      ...?headers,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(jsonBody),
  );
}
