part of '../response.dart';

/// Represents a get user info response.
class GetUserInfoResponse extends BackendResponse {
  /// The user.
  final User user;

  /// Creates a new get user info response instance.
  const GetUserInfoResponse({
    required this.user,
  });

  /// Creates a new get user info response instance from a JSON map.
  GetUserInfoResponse.fromJson(JsonMap json)
    : this(
        user: User.fromJson(json),
      );
}

/// Represents a delete user response.
class DeleteUserResponse extends BackendResponse {
  /// Creates a new delete user response instance.
  const DeleteUserResponse();

  /// Creates a new delete user response instance from a JSON map.
  const DeleteUserResponse.fromJson(JsonMap json) : this();
}
