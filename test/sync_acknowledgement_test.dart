import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/backend/request/response.dart';
import 'package:open_authenticator/core/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/core/backend/synchronization/push/result.dart';
import 'package:open_authenticator/core/database/database.dart';

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('a partial push reply retains only retryable and unacknowledged entries', () async {
    const Map<String, Object> record = {
      'secret': [1, 2],
      'encryptionSalt': [3],
      'updatedAt': 1500,
    };
    await database.addPendingBackendPushOperation(
      SetTotpsPushOperation.raw(
        uuid: 'batch',
        payload: {
          for (final String id in ['accepted', 'stale', 'overQuota', 'unanswered']) id: record,
        },
      ),
    );
    await database.applyPushResponse(
      SynchronizationPushResponse.fromJson([
        {'operationUuid': 'batch', 'totpUuid': 'accepted'},
        {'operationUuid': 'batch', 'totpUuid': 'stale', 'errorCode': 'invalidUpdateTimestamp'},
        {'operationUuid': 'batch', 'totpUuid': 'overQuota', 'errorCode': 'tooManyTotps', 'errorDetails': 'quota reached'},
      ]),
    );

    final PushOperation pending = (await database.listPendingBackendPushOperations()).single;
    expect(pending.uuid, 'batch');
    expect(pending.payload, {'overQuota': record, 'unanswered': record});
    final List<PushOperationError> errors = await database.watchBackendPushOperationErrors().first;
    expect(
      errors.map((error) => (error.totpUuid, error.errorKind, error.errorDetails)),
      unorderedEquals([
        ('stale', PushOperationErrorKind.invalidUpdateTimestamp, null),
        ('overQuota', PushOperationErrorKind.tooManyTotps, 'quota reached'),
      ]),
    );
  });

  test('an interrupted acknowledgement can be replayed without losing operations or duplicating errors', () async {
    await database.addPendingBackendPushOperation(DeleteTotpsPushOperation.raw(uuid: 'first', payload: {'a': 1500}));
    await database.addPendingBackendPushOperation(DeleteTotpsPushOperation.raw(uuid: 'second', payload: {'b': 1600}));
    final response = SynchronizationPushResponse.fromJson([
      {'operationUuid': 'first', 'totpUuid': 'a'},
      {'operationUuid': 'second', 'totpUuid': 'b', 'errorCode': 'invalidDeleteTimestamp'},
    ]);
    await database.customStatement(
      "CREATE TRIGGER reject_sync_error BEFORE INSERT ON backend_push_operation_errors BEGIN SELECT RAISE(ABORT, 'test write interrupted'); END",
    );
    await expectLater(database.applyPushResponse(response), throwsA(predicate<Object>((error) => error.toString().contains('test write interrupted'))));
    final List<PushOperation> pending = await database.listPendingBackendPushOperations();
    expect(
      {for (final operation in pending) operation.uuid: operation.payload},
      {
        'first': {'a': 1500},
        'second': {'b': 1600},
      },
    );
    expect(await database.watchBackendPushOperationErrors().first, isEmpty);

    await database.customStatement('DROP TRIGGER reject_sync_error');
    await database.applyPushResponse(response);
    await database.applyPushResponse(response);
    expect(await database.listPendingBackendPushOperations(), isEmpty);
    final PushOperationError error = (await database.watchBackendPushOperationErrors().first).single;
    expect((error.operationUuid, error.totpUuid, error.errorKind), ('second', 'b', PushOperationErrorKind.invalidDeleteTimestamp));
  });
}
