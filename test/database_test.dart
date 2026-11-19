import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Migrator, Table, TableInfo;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/backend/request/response.dart';
import 'package:open_authenticator/core/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/core/backend/synchronization/push/result.dart';
import 'package:open_authenticator/core/crypto/salt.dart';
import 'package:open_authenticator/core/database/database.dart';
import 'package:open_authenticator/core/database/database.steps.dart';
import 'package:open_authenticator/core/totp/totp.dart';

void main() {
  late AppDatabase database;

  Totp createTotp(String uuid) => Totp(
    uuid: uuid,
    encryptedData: EncryptedData(
      encryptedSecret: Uint8List.fromList([1, 2, 3]),
      encryptedLabel: Uint8List.fromList([4]),
      encryptionSalt: Salt.fromRawValue(value: Uint8List.fromList([5, 6])),
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  );

  test('reads scheduled by a key change use the committed vault on the background database', () async {
    final Directory directory = await Directory.systemTemp.createTemp('openauthenticator-key-change-');
    final db = AppDatabase.forTesting(NativeDatabase.createInBackground(File('${directory.path}/vault.sqlite')));
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
    final committed = Completer<void>();
    late Future<List<Totp>> refreshed;
    await db.transactionWithCredentials(
      writeVault: () => db.addTotps([createTotp('saved')]),
      updateCredentials: () async {
        refreshed = committed.future.then((_) => db.listTotps());
      },
    );
    committed.complete();
    expect((await refreshed).single.uuid, 'saved');
  });

  group('database mutations', () {
    setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => database.close());
    test('markAsDeleted only keeps the newest tombstones', () async {
      await database.markAsDeleted({
        'a': DateTime.fromMillisecondsSinceEpoch(2000),
        'b': DateTime.fromMillisecondsSinceEpoch(2000),
      });
      await database.markAsDeleted({
        'a': DateTime.fromMillisecondsSinceEpoch(1000),
        'b': DateTime.fromMillisecondsSinceEpoch(3000),
        'c': DateTime.fromMillisecondsSinceEpoch(1000),
      });
      expect(await database.getDeletedTotps(), {
        'a': DateTime.fromMillisecondsSinceEpoch(2000),
        'b': DateTime.fromMillisecondsSinceEpoch(3000),
        'c': DateTime.fromMillisecondsSinceEpoch(1000),
      });
    });

    test('deleteTotps deletes and marks TOTPs as deleted', () async {
      await database.addTotps([createTotp('a'), createTotp('b')]);
      await database.deleteTotps({'a': DateTime.fromMillisecondsSinceEpoch(5000)});
      expect((await database.listTotps()).map((totp) => totp.uuid), ['b']);
      expect(await database.getDeletedTotps(), {'a': DateTime.fromMillisecondsSinceEpoch(5000)});
    });

    test('replaceTotps replaces TOTPs and tombstones', () async {
      await database.addTotps([createTotp('a'), createTotp('b')]);
      await database.markAsDeleted({'c': DateTime.fromMillisecondsSinceEpoch(1000)});
      await database.replaceTotps([createTotp('c')], {'a': DateTime.fromMillisecondsSinceEpoch(4000)});
      expect((await database.listTotps()).map((totp) => totp.uuid), ['c']);
      expect(await database.getDeletedTotps(), {'a': DateTime.fromMillisecondsSinceEpoch(4000)});
    });

    test('a failed outbox write rolls back the vault and its deletion marks', () async {
      await database.saveTotps([createTotp('a')]);
      await database.customStatement("CREATE TRIGGER fail_push BEFORE INSERT ON pending_backend_push_operations BEGIN SELECT RAISE(ABORT, 'outbox unavailable'); END");
      await expectLater(database.saveTotps([createTotp('b')], replace: true, enqueue: true), throwsA(anything));
      await expectLater(database.deleteTotps({'a': DateTime.now()}, enqueue: true), throwsA(anything));
      expect((await database.listTotps()).map((totp) => totp.uuid), ['a']);
      expect(await database.getDeletedTotps(), isEmpty);
      expect(await database.listPendingBackendPushOperations(), isEmpty);
    });

    test('older queued entries retain their ciphertext with supported generation parameters', () async {
      await database.addPendingBackendPushOperation(
        SetTotpsPushOperation.raw(
          payload: {
            'a': {
              'validity': 0,
              'digits': 2,
              'secret': [1, 2],
            },
            'b': {
              'validity': 60,
              'digits': 8,
              'secret': [3],
            },
          },
        ),
      );
      expect((await database.listPendingBackendPushOperations()).single.payload, {
        'a': {
          'secret': [1, 2],
        },
        'b': {
          'validity': 60,
          'digits': 8,
          'secret': [3],
        },
      });
    });

    test('a late reply keeps a retry behind edits queued while the request was running', () async {
      final date = DateTime.fromMillisecondsSinceEpoch(1345);
      final first = DeleteTotpsPushOperation.raw(uuid: 'first', createdAt: date, payload: {'a': 1345, 'b': 1345, 'c': 1345});
      await database.addPendingBackendPushOperation(first);
      expect((await database.compactPendingOperations()).single.createdAt, date);
      await database.addPendingBackendPushOperation(DeleteTotpsPushOperation.raw(uuid: 'second', createdAt: date, payload: {'b': 1367}));
      await database.applyPushResponse(
        SynchronizationPushResponse(
          result: [
            PushOperationResult(operationUuid: 'first', totpUuid: 'a'),
            PushOperationResult(operationUuid: 'first', totpUuid: 'b', errorCode: 'genericError'),
            PushOperationResult(operationUuid: 'first', totpUuid: 'c', errorCode: 'genericError'),
          ],
        ),
      );
      final List<PushOperation> operations = await database.compactPendingOperations();
      expect(operations.map((operation) => operation.uuid), ['second', 'first']);
      expect(operations.first.payload, {'b': 1367});
      expect(operations.last.payload, {'c': 1345});
    });

    test('network changes honor millisecond timestamps and deletion wins ties', () async {
      final date = DateTime.fromMillisecondsSinceEpoch(1537);
      final Totp totp = createTotp('a').copyWith(updatedAt: date);
      await database.saveTotps([totp]);
      expect((await database.listTotps()).single.updatedAt, date);
      await database.deleteTotps({'a': date.subtract(const Duration(milliseconds: 1))});
      expect(await database.listTotps(), hasLength(1));
      await database.deleteTotps({'a': date});
      await database.saveTotps([totp], fromNetwork: true);
      expect(await database.listTotps(), isEmpty);
      expect(await database.getDeletedTotps(), {'a': date});
    });
  });
  for (final version in [1, 2]) {
    test('opens a version $version vault and retains its timestamps and pending operations', () async {
      final Directory directory = await Directory.systemTemp.createTemp('open-authenticator-migration-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/test.sqlite');
      final old = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await old.customSelect('SELECT 1').get();
        final migrator = Migrator(old);
        for (final TableInfo<Table, Object?> table in old.allTables) {
          await migrator.drop(table);
        }
        final schema = Schema2(database: old);
        await migrator.createTable(schema.totps);
        if (version == 1) {
          await old.customStatement('ALTER TABLE totps DROP COLUMN updated_at');
        } else {
          await migrator.createTable(schema.deletedTotps);
          await migrator.createTable(schema.pendingBackendPushOperations);
          await migrator.createTable(schema.backendPushOperationErrors);
          await old.customStatement("INSERT INTO deleted_totps VALUES ('removed', 12)");
          for (final id in ['earlier', 'later']) {
            await old.customStatement('INSERT INTO pending_backend_push_operations (uuid, kind, json_payload, created_at) VALUES (?, ?, ?, ?)', [id, 'delete', '{"a":12345}', 12]);
          }
        }
        await old.customStatement("INSERT INTO totps (uuid, secret, encryption_salt, validity) VALUES ('active', 'AQ==', 'Ag==', 0)");
        if (version == 2) {
          await old.customStatement('UPDATE totps SET updated_at = 13');
        }
        await old.customStatement('PRAGMA user_version = $version');
      } finally {
        await old.close();
      }
      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(reopened.close);
      final Totp record = (await reopened.listTotps()).single;
      expect(record.validity, isNull);
      expect(record.updatedAt.millisecondsSinceEpoch, version == 1 ? 0 : 13000);
      if (version == 2) {
        expect((await reopened.getDeletedTotps())['removed']?.millisecondsSinceEpoch, 12000);
        final List<PushOperation> operations = await reopened.listPendingBackendPushOperations();
        expect(operations.map((operation) => operation.uuid), ['later', 'earlier']);
        expect(operations.first.createdAt.millisecondsSinceEpoch, 12000);
      }
    });
  }
}
