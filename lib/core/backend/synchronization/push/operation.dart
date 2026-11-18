import 'package:equatable/equatable.dart';
import 'package:open_authenticator/core/database/database.dart';
import 'package:open_authenticator/core/totp/json.dart';
import 'package:open_authenticator/core/totp/totp.dart';
import 'package:open_authenticator/utils/json.dart';
import 'package:uuid/uuid.dart';

/// Represents a push operation.
sealed class PushOperation<T extends JsonMap> with Equatable {
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
  PushOperationKind get _kind;

  @override
  List<Object?> get props => [
    uuid,
    _kind,
    payload,
    createdAt,
  ];

  /// Converts the push operation to a JSON map.
  JsonMap toJson({
    bool httpRequest = false,
  }) => {
    'uuid': uuid,
    'payload': payload,
    'kind': _kind.name,
    if (!httpRequest) ...{
      'createdAt': createdAt.millisecondsSinceEpoch,
    },
  };
}

/// Represents a `set` push operation.
class SetTotpsPushOperation extends PushOperation<JsonMap> {
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

  /// Creates a new `set` push operation instance from a raw payload.
  SetTotpsPushOperation.raw({
    super.uuid,
    required super.payload,
    super.createdAt,
  });

  @override
  PushOperationKind get _kind => PushOperationKind.set;

  @override
  SetTotpsPushOperation copyWith({
    JsonMap? payload,
    DateTime? createdAt,
  }) => SetTotpsPushOperation.raw(
    uuid: uuid,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// Represents a `delete` push operation.
class DeleteTotpsPushOperation extends PushOperation<Map<String, int>> {
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

  /// Creates a new `delete` push operation instance from a raw payload.
  DeleteTotpsPushOperation.raw({
    super.uuid,
    required super.payload,
    super.createdAt,
  });

  @override
  PushOperationKind get _kind => PushOperationKind.delete;

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

/// Represents a push operation kind.
enum PushOperationKind {
  /// Represents a delete operation.
  delete,

  /// Represents a set operation.
  set,
}

/// Allows to compact a list of push operations.
extension Compact on List<PushOperation> {
  /// Compacts operations supplied in newest insertion order first. Only the latest operation for each TOTP UUID is kept.
  List<PushOperation> get compacted {
    if (isEmpty) {
      return [];
    }

    final Set<String> processedTotpUuids = {};
    final List<PushOperation> result = [];

    for (final PushOperation operation in this) {
      switch (operation) {
        case SetTotpsPushOperation(:final payload):
          final JsonMap newPayload = {
            for (final MapEntry<String, dynamic> entry in payload.entries)
              if (processedTotpUuids.add(entry.key)) entry.key: entry.value,
          };
          if (newPayload.isNotEmpty) {
            result.add(operation.copyWith(payload: newPayload));
          }
          break;
        case DeleteTotpsPushOperation(:final payload):
          final Map<String, int> newPayload = {
            for (final MapEntry<String, int> entry in payload.entries)
              if (processedTotpUuids.add(entry.key)) entry.key: entry.value,
          };
          if (newPayload.isNotEmpty) {
            result.add(operation.copyWith(payload: newPayload));
          }
          break;
      }
    }

    return result;
  }
}
