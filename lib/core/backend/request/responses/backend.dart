part of '../response.dart';

/// Represents a ping backend response.
class PingBackendResponse extends BackendResponse {
  /// Creates a new ping backend response instance.
  const PingBackendResponse();

  /// Creates a new ping backend response instance from a JSON map.
  const PingBackendResponse.fromJson(JsonMap json) : this();
}
