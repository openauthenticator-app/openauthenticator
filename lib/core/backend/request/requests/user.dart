part of '../request.dart';

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
