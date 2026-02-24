import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/model/backend/synchronization/push/result.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/database/database.steps.dart';
import 'package:open_authenticator/model/totp/algorithm.dart';
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/drift.dart';
import 'package:open_authenticator/utils/riverpod.dart';
import 'package:open_authenticator/utils/sqlite.dart';

part 'database.g.dart';
part 'extensions.dart';
part 'tables.dart';

/// The app database provider.
final appDatabaseProvider = Provider.autoDispose<AppDatabase>((ref) {
  AppDatabase storage = AppDatabase();
  ref.onDispose(storage.close);
  ref.cacheFor(const Duration(seconds: 1));
  return storage;
});

/// Stores totps, deleted totps, pending backend push operations and backend push operation errors.
@DriftDatabase(tables: [Totps, DeletedTotps, PendingBackendPushOperations, BackendPushOperationErrors])
class AppDatabase extends _$AppDatabase {
  /// The database file name.
  static const _kDbFileName = 'app';

  /// Creates a new Drift storage instance.
  AppDatabase() : super(SqliteUtils.openConnection(_kDbFileName));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(onUpgrade: schemaUpgrade);

  /// Stores the given [totp].
  Future<void> addTotp(Totp totp) async {
    await into(totps).insert(totp.asDriftTotp);
  }

  /// Stores the given [totps].
  Future<void> addTotps(List<Totp> totps) async {
    await batch((batch) {
      batch.insertAll(
        this.totps,
        totps.map((totp) => totp.asDriftTotp),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// Deletes the TOTP associated to the given [uuid].
  Future<void> deleteTotp(String uuid) async {
    await (delete(totps)..where((totp) => totp.uuid.isValue(uuid))).go();
  }

  /// Deletes the TOTP associated to the given [uuids].
  Future<void> deleteTotps(List<String> uuids) async {
    await (delete(totps)..where((totp) => totp.uuid.isIn(uuids))).go();
  }

  /// Updates the [totp].
  Future<void> updateTotp(Totp totp) async {
    await update(totps).replace(totp.asDriftTotp);
  }

  /// Updates all [totps].
  Future<void> updateTotps(List<Totp> totps) async {
    await batch((batch) {
      batch.replaceAll(
        this.totps,
        [
          for (Totp totp in totps) totp.asDriftTotp,
        ],
      );
    });
  }

  /// Returns the TOTP associated to the given [uuid].
  Future<Totp?> getTotp(String uuid) async {
    _DriftTotp? totp =
        await (select(totps)
              ..where((totp) => totp.uuid.isValue(uuid))
              ..limit(1))
            .getSingleOrNull();
    return totp?.asTotp;
  }

  // @override
  // Stream<List<Totp>> watchTotps() => select(totps).watch().map((list) => [
  //       for (_DriftTotp driftTotp in list) driftTotp.asTotp,
  //     ]);

  /// Lists all TOTPs.
  Future<List<Totp>> listTotps() => _selectAllTotps().map((totp) => totp.asTotp).get();

  /// Lists all TOTPs UUID.
  Future<List<String>> listUuids() => _selectAllTotps().map((totp) => totp.uuid).get();

  /// Selects all TOTPs.
  SimpleSelectStatement<$TotpsTable, _DriftTotp> _selectAllTotps() => select(totps)..orderBy([(table) => OrderingTerm(expression: table.issuer)]);

  /// Replace all current TOTPs by [newTotps].
  Future<void> replaceTotps(List<Totp> newTotps) => batch((batch) {
    batch.deleteAll(totps);
    batch.insertAll(totps, newTotps.map((totp) => totp.asDriftTotp));
  });

  /// Returns all deleted TOTPs.
  Future<List<String>> getDeletedUuids() async {
    return await (select(deletedTotps)).map((deletedTotp) => deletedTotp.uuid).get();
  }

  /// Marks the given [uuids] as deleted.
  Future<void> markAsDeleted(List<String> uuids) async {
    await batch((batch) {
      batch.insertAll(
        deletedTotps,
        uuids.map((uuid) => _DriftDeletedTotp(uuid: uuid)),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Marks the given [totp] as not deleted.
  Future<void> removeDeletionMark(String uuid) async {
    await (delete(deletedTotps)..where((deletedTotp) => deletedTotp.uuid.isValue(uuid))).go();
  }

  /// Returns whether the given [uuid] is deleted.
  Future<bool> isMarkedAsDeleted(String uuid) async {
    _DriftDeletedTotp? deletedTotp =
        await (select(deletedTotps)
              ..where((deletedTotp) => deletedTotp.uuid.isValue(uuid))
              ..limit(1))
            .getSingleOrNull();
    return deletedTotp != null;
  }

  /// Returns the push operation associated to the given [uuid].
  Future<PushOperation?> getPendingBackendPushOperation(String uuid) async {
    _DriftBackendPushOperation? operation =
        await (select(pendingBackendPushOperations)
              ..where((operation) => operation.uuid.isValue(uuid))
              ..limit(1))
            .getSingleOrNull();
    return operation?.asBackendPushOperation;
  }

  /// Selects the pending backend push operations.
  Selectable<PushOperation> _selectPendingBackendPushOperations() {
    SimpleSelectStatement<$PendingBackendPushOperationsTable, _DriftBackendPushOperation> operations = select(pendingBackendPushOperations)..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return operations.map((operation) => operation.asBackendPushOperation);
  }

  /// Returns the pending backend push operations.
  Future<List<PushOperation>> listPendingBackendPushOperations() => _selectPendingBackendPushOperations().get();

  /// Returns the stream of pending backend push operations.
  Stream<List<PushOperation>> watchPendingBackendPushOperations() => _selectPendingBackendPushOperations().watch();

  /// Adds a new pending backend push operation.
  Future<void> addPendingBackendPushOperation(PushOperation operation) async {
    await into(pendingBackendPushOperations).insert(operation.asDriftBackendPushOperation);
  }

  /// Replaces all pending backend push operations by [operations].
  Future<void> replacePendingBackendPushOperations(List<PushOperation> operations) async {
    await batch((batch) {
      batch.deleteAll(pendingBackendPushOperations);
      batch.insertAll(
        pendingBackendPushOperations,
        [
          for (PushOperation operation in operations) operation.asDriftBackendPushOperation,
        ],
      );
    });
  }

  /// Deletes the pending backend push operation associated to the given [operation].
  Future<void> deletePendingBackendPushOperation(PushOperation operation) async {
    await (delete(pendingBackendPushOperations)..where((pendingOperation) => pendingOperation.uuid.isValue(operation.uuid))).go();
  }

  /// Applies the given push response.
  Future<void> applyPushResponse(SynchronizationPushResponse value) async {
    Set<String> toDelete = {};
    Map<String, List<PushOperationResult>> resultsWithErrors = {};
    for (PushOperationResult result in value.result) {
      toDelete.add(result.totpUuid);
      if (!result.success) {
        resultsWithErrors.putIfAbsent(result.totpUuid, () => []).add(result);
      }
    }
    List<_DriftBackendPushOperation> toRetry = [];
    List<_DriftBackendPushOperationError> errors = [];
    for (MapEntry<String, List<PushOperationResult>> entry in resultsWithErrors.entries) {
      List<Totp> toSet = [];
      List<String> toDelete = [];
      for (PushOperationResult result in entry.value) {
        if (!result.errorKind!.isPermanent) {
          PushOperation? operation = await getPendingBackendPushOperation(result.operationUuid);
          if (operation != null) {
            switch (operation) {
              case SetTotpsPushOperation(:final payload):
                Map<String, dynamic>? totpData = payload[result.totpUuid];
                if (totpData != null) {
                  toSet.add(JsonTotp.fromJson(totpData, uuid: result.totpUuid));
                }
                break;
              case DeleteTotpsPushOperation():
                toDelete.add(result.totpUuid);
                break;
            }
          }
        }
        errors.add(result.asDriftBackendPushOperationError);
      }
      if (toSet.isNotEmpty) {
        toRetry.add(SetTotpsPushOperation(totps: toSet).asDriftBackendPushOperation);
      }
      if (toDelete.isNotEmpty) {
        toRetry.add(DeleteTotpsPushOperation(uuids: toDelete).asDriftBackendPushOperation);
      }
    }
    await batch((batch) {
      batch.deleteWhere(pendingBackendPushOperations, (operation) => operation.uuid.isIn(toDelete));
      batch.insertAll(pendingBackendPushOperations, toRetry);
      batch.insertAll(backendPushOperationErrors, errors);
    });
  }

  /// Selects the backend push operation errors.
  Selectable<PushOperationError> _selectBackendPushOperationErrors() {
    SimpleSelectStatement<$BackendPushOperationErrorsTable, _DriftBackendPushOperationError> operations = select(backendPushOperationErrors)..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return operations.map((operation) => operation.asBackendPushOperationResult as PushOperationError);
  }

  /// Returns the backend push operation errors.
  Future<List<PushOperationError>> listBackendPushOperationErrors() => _selectBackendPushOperationErrors().get();

  /// Returns the stream of backend push operation errors.
  Stream<List<PushOperationError>> watchBackendPushOperationErrors() => _selectBackendPushOperationErrors().watch();

  /// Adds a new backend push operation error.
  Future<void> deleteBackendPushOperationError(PushOperationError error) async {
    assert(!error.success, 'Cannot delete a successful operation.');
    await (delete(backendPushOperationErrors)..where(
          (operation) =>
              operation.totpUuid.isValue(error.totpUuid) &
              operation.operationUuid.isValue(error.operationUuid) &
              operation.errorKind.isValue(error.errorCode) &
              operation.errorDetails.isValue(error.errorDetails!) &
              operation.createdAt.isValue(error.createdAt.millisecondsSinceEpoch),
        ))
        .go();
  }

  /// Deletes all backend push operation errors.
  Future<void> clearBackendPushOperationErrors() async {
    await (delete(backendPushOperationErrors)).go();
  }

  /// Clears all totps, deleted totps, pending backend push operations and backend push operation errors.
  Future<void> clear() => batch((batch) {
    batch.deleteAll(totps);
    batch.deleteAll(deletedTotps);
    batch.deleteAll(pendingBackendPushOperations);
    batch.deleteAll(backendPushOperationErrors);
  });
}

/// Allows to migrate the database scheme to the latest version.
extension _Migrations on GeneratedDatabase {
  /// Returns the migration strategy.
  OnUpgrade get schemaUpgrade => stepByStep(
    from1To2: (migrator, schema) async {
      await migrator.createTable(schema.deletedTotps);
      await migrator.createTable(schema.pendingBackendPushOperations);
      await migrator.createTable(schema.backendPushOperationErrors);
    },
  );
}
