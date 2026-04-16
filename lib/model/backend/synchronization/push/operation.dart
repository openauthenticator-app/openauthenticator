import 'package:equatable/equatable.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:uuid/uuid.dart';

/// Represents a push operation.
sealed class PushOperation<T> with EquatableMixin {
  /// The operation UUID.
  final String uuid;

  /// The operation creation date.
  final DateTime createdAt;

  /// The operation payload.
  final T payload;

  /// Creates a new push operation instance.
  PushOperation({
    String? uuid,
    DateTime? createdAt,
    required this.payload,
  }) : uuid = uuid ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Creates a copy of the push operation.
  PushOperation copyWith({
    T? payload,
    DateTime? createdAt,
  });

  /// The operation kind.
  String get _kind;

  @override
  List<Object?> get props => [
    uuid,
    _kind,
    payload,
    createdAt,
  ];

  /// Converts the push operation to a JSON map.
  Map<String, dynamic> toJson({
    bool httpRequest = false,
  }) => {
    'uuid': uuid,
    'payload': payload,
    'kind': _kind,
    if (!httpRequest) ...{
      'createdAt': createdAt.millisecondsSinceEpoch,
    },
  };
}

/// Represents a `set` push operation.
class SetTotpsPushOperation extends PushOperation<Map<String, dynamic>> {
  /// Creates a new `set` push operation instance from a raw payload.
  SetTotpsPushOperation.raw({
    super.uuid,
    required super.payload,
    super.createdAt,
  });

  /// Creates a new `set` push operation instance from a TOTPs list.
  SetTotpsPushOperation({
    String? uuid,
    required List<Totp> totps,
    DateTime? createdAt,
  }) : this.raw(
         uuid: uuid,
         payload: {
           for (Totp totp in totps) totp.uuid: totp.toJson(includeUuid: false),
         },
         createdAt: createdAt,
       );

  @override
  String get _kind => 'set';

  @override
  SetTotpsPushOperation copyWith({
    Map<String, dynamic>? payload,
    DateTime? createdAt,
  }) => SetTotpsPushOperation.raw(
    uuid: uuid,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// Represents a `delete` push operation.
class DeleteTotpsPushOperation extends PushOperation<Map<String, int>> {
  /// Creates a new `delete` push operation instance from a raw payload.
  DeleteTotpsPushOperation.raw({
    super.uuid,
    required super.payload,
    super.createdAt,
  });

  /// Creates a new `delete` push operation instance from a UUIDs list.
  DeleteTotpsPushOperation({
    String? uuid,
    required DeletedTotpMap tombstones,
    DateTime? createdAt,
  }) : this.raw(
         uuid: uuid,
         payload: {
           for (MapEntry<String, DateTime> entry in tombstones.entries) entry.key: entry.value.millisecondsSinceEpoch,
         },
         createdAt: createdAt,
       );

  @override
  String get _kind => 'delete';

  @override
  DeleteTotpsPushOperation copyWith({
    Map<String, int>? payload,
    DateTime? createdAt,
  }) => DeleteTotpsPushOperation.raw(
    uuid: uuid,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// Allows to compact a list of push operations.
extension Compact on List<PushOperation> {
  /// Compacts the current push operations while preserving their relative order.
  /// Only the latest operation for each TOTP UUID is kept.
  List<PushOperation> get compacted {
    if (isEmpty) {
      return [];
    }

    Set<String> processedTotpUuids = {};
    List<PushOperation> result = [];

    for (PushOperation operation in reversed) {
      switch (operation) {
        case SetTotpsPushOperation(:final payload):
          Map<String, dynamic> newPayload = {
            for (MapEntry<String, dynamic> entry in payload.entries)
              if (processedTotpUuids.add(entry.key)) entry.key: entry.value,
          };
          if (newPayload.isNotEmpty) {
            result.add(operation.copyWith(payload: newPayload));
          }
          break;
        case DeleteTotpsPushOperation(:final payload):
          Map<String, int> newPayload = {
            for (MapEntry<String, int> entry in payload.entries)
              if (processedTotpUuids.add(entry.key)) entry.key: entry.value,
          };
          if (newPayload.isNotEmpty) {
            result.add(operation.copyWith(payload: newPayload));
          }
          break;
      }
    }

    return result.reversed.toList();
  }
}
