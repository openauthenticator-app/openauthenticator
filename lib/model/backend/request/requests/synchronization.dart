part of '../request.dart';

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
    for (final PushOperation operation in operations) operation.toJson(httpRequest: true),
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
