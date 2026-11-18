part of '../request.dart';

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
