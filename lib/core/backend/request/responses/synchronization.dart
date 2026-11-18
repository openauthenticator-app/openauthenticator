part of '../response.dart';

/// Represents a get user TOTPs response.
class GetUserTotpsResponse extends BackendResponse {
  /// The TOTPs.
  final List<Totp> totps;

  /// Creates a new get user TOTPs response instance.
  const GetUserTotpsResponse({
    this.totps = const [],
  });

  /// Creates a new get user TOTPs response instance from a JSON map.
  GetUserTotpsResponse.fromJson(JsonMap json)
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
  final Map<String, DateTime> deletes;

  /// Creates a new synchronization pull response instance.
  const SynchronizationPullResponse({
    this.inserts = const [],
    this.updates = const [],
    this.deletes = const {},
  });

  /// Creates a new synchronization pull response instance from a JSON map.
  SynchronizationPullResponse.fromJson(JsonMap json)
    : this(
        inserts: _totpListFromJson(json['inserts']),
        updates: _totpListFromJson(json['updates']),
        deletes: (json['deletes'] as Map).map((key, value) => MapEntry(key, DateTime.fromMillisecondsSinceEpoch(value))),
      );

  /// Creates a new synchronization pull response instance from a JSON map.
  static List<Totp> _totpListFromJson(Map json) => [
    for (final String uuid in json.keys)
      JsonTotp.fromJson(
        json[uuid],
        uuid: uuid,
      ),
  ];
}
