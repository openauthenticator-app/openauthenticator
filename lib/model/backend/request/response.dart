import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/synchronization/push/result.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/totp.dart';

/// Represents a backend response.
abstract class BackendResponse {
  /// Creates a new backend response instance.
  const BackendResponse();
}

/// Represents a get user info response.
class GetUserInfoResponse extends BackendResponse {
  /// The user.
  final User user;

  /// Creates a new get user info response instance.
  const GetUserInfoResponse({
    required this.user,
  });

  /// Creates a new get user info response instance from a JSON map.
  GetUserInfoResponse.fromJson(Map<String, dynamic> json)
    : this(
        user: User.fromJson(json),
      );
}

/// Represents a delete user response.
class DeleteUserResponse extends BackendResponse {
  /// Creates a new delete user response instance.
  const DeleteUserResponse();

  /// Creates a new delete user response instance from a JSON map.
  const DeleteUserResponse.fromJson(Map<String, dynamic> json) : this();
}

/// Represents a get user TOTPs response.
class GetUserTotpsResponse extends BackendResponse {
  /// The TOTPs.
  final List<Totp> totps;

  /// Creates a new get user TOTPs response instance.
  const GetUserTotpsResponse({
    this.totps = const [],
  });

  /// Creates a new get user TOTPs response instance from a JSON map.
  GetUserTotpsResponse.fromJson(Map<String, dynamic> json)
    : this(
        totps: [
          for (String uuid in json.keys)
            JsonTotp.fromJson(
              json[uuid],
              uuid: uuid,
            ),
        ],
      );
}

/// Represents a refresh token response.
class RefreshSessionResponse extends BackendResponse {
  /// The access token.
  final Session session;

  /// Creates a new refresh token response instance.
  const RefreshSessionResponse({
    required this.session,
  });

  /// Creates a new refresh token response instance from a JSON map.
  RefreshSessionResponse.fromJson(Map<String, dynamic> json)
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
  const UserLogoutResponse.fromJson(Map<String, dynamic> json) : this();
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
  final Session session;

  const ProviderLoginResponse({
    required this.session,
  });

  /// Creates a new provider login response instance from a JSON map.
  ProviderLoginResponse.fromJson(Map<String, dynamic> json)
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
  const EmailConfirmationCancelResponse.fromJson(Map<String, dynamic> json) : this();
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
  ProviderLinkResponse.fromJson(Map<String, dynamic> json)
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
  const ProviderUnlinkResponse.fromJson(Map<String, dynamic> json) : this();
}

/// Represents a synchronization push response.
class SynchronizationPushResponse extends BackendResponse {
  /// The push operation results.
  final List<PushOperationResult> result;

  /// Creates a new synchronization push response instance.
  const SynchronizationPushResponse({
    this.result = const [],
  });

  /// Creates a new synchronization push response instance from a JSON list.
  SynchronizationPushResponse.fromJson(List json)
    : this(
        result: json.map((json) => PushOperationResult.fromJson(json)).toList(),
      );
}

/// Represents a synchronization pull response.
class SynchronizationPullResponse extends BackendResponse {
  /// The TOTPs to insert.
  final List<Totp> inserts;

  /// The TOTPs to update.
  final List<Totp> updates;

  /// The TOTPs to delete.
  final List<String> deletes;

  /// Creates a new synchronization pull response instance.
  const SynchronizationPullResponse({
    this.inserts = const [],
    this.updates = const [],
    this.deletes = const [],
  });

  /// Creates a new synchronization pull response instance from a JSON map.
  SynchronizationPullResponse.fromJson(Map<String, dynamic> json)
    : this(
        inserts: _totpListFromJson(json['inserts']),
        updates: _totpListFromJson(json['updates']),
        deletes: (json['deletes'] as List).cast<String>(),
      );

  /// Creates a new synchronization pull response instance from a JSON map.
  static List<Totp> _totpListFromJson(Map json) => [
    for (String uuid in json.keys)
      JsonTotp.fromJson(
        json[uuid],
        uuid: uuid,
      ),
  ];
}
