import 'package:equatable/equatable.dart';
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
class DeleteTotpsPushOperation extends PushOperation<List<String>> {
  /// Creates a new `delete` push operation instance from a raw payload.
  DeleteTotpsPushOperation.raw({
    super.uuid,
    required super.payload,
    super.createdAt,
  });

  /// Creates a new `delete` push operation instance from a UUIDs list.
  DeleteTotpsPushOperation({
    String? uuid,
    required List<String> uuids,
    DateTime? createdAt,
  }) : this.raw(
         uuid: uuid,
         payload: uuids,
         createdAt: createdAt,
       );

  @override
  String get _kind => 'delete';

  @override
  DeleteTotpsPushOperation copyWith({
    List<String>? payload,
    DateTime? createdAt,
  }) => DeleteTotpsPushOperation.raw(
    uuid: uuid,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
}
