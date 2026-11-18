part of '../response.dart';

/// Represents a refresh token response.
class RefreshSessionResponse extends BackendResponse {
  /// The access token.
  final Session session;

  /// Creates a new refresh token response instance.
  const RefreshSessionResponse({
    required this.session,
  });

  /// Creates a new refresh token response instance from a JSON map.
  RefreshSessionResponse.fromJson(JsonMap json)
    : this(
        session: Session(
          accessToken: json['accessToken'],
          refreshToken: json['refreshToken'],
        ),
      );
}

/// Represents a user logout response.
class UserLogoutResponse extends BackendResponse {
  /// Creates a new user logout response instance.
  const UserLogoutResponse();

  /// Creates a new user logout response instance from a JSON map.
  const UserLogoutResponse.fromJson(JsonMap json) : this();
}

/// Represents an email confirm response.
class EmailConfirmResponse extends BackendResponse {
  /// The confirmation URL.
  final Uri url;

  /// Creates a new email confirm response instance.
  const EmailConfirmResponse({
    required this.url,
  });

  /// Creates a new email confirm response instance from a JSON string.
  EmailConfirmResponse.fromJson(String json)
    : this(
        url: Uri.parse(json),
      );
}

/// Represents a provider login response.
class ProviderLoginResponse extends BackendResponse {
  /// The created session.
  final Session session;

  /// Creates a new provider login response instance.
  const ProviderLoginResponse({
    required this.session,
  });

  /// Creates a new provider login response instance from a JSON map.
  ProviderLoginResponse.fromJson(JsonMap json)
    : this(
        session: Session(
          accessToken: json['accessToken'],
          refreshToken: json['refreshToken'],
        ),
      );
}

/// Represents an email confirmation cancel response.
class EmailConfirmationCancelResponse extends BackendResponse {
  /// Creates a new email confirmation cancel response instance.
  const EmailConfirmationCancelResponse();

  /// Creates a new email confirmation cancel response instance from a JSON map.
  const EmailConfirmationCancelResponse.fromJson(JsonMap json) : this();
}

/// Represents a provider link response.
class ProviderLinkResponse extends BackendResponse {
  /// The user id.
  final String userId;

  /// The provider user id.
  final String providerUserId;

  /// Creates a new provider link response instance.
  const ProviderLinkResponse({
    required this.userId,
    required this.providerUserId,
  });

  /// Creates a new provider link response instance from a JSON map.
  ProviderLinkResponse.fromJson(JsonMap json)
    : this(
        userId: json['userId'],
        providerUserId: json['providerUserId'],
      );
}

/// Represents a provider unlink response.
class ProviderUnlinkResponse extends BackendResponse {
  /// Creates a new provider unlink response instance.
  const ProviderUnlinkResponse();

  /// Creates a new provider unlink response instance from a JSON map.
  const ProviderUnlinkResponse.fromJson(JsonMap json) : this();
}
