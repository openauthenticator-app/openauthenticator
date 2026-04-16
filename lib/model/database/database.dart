import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';
part 'extensions.dart';
part 'tables.dart';

/// A map of deleted TOTPs.
typedef DeletedTotpMap = Map<String, DateTime>;

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

  /// The legacy database file name.
  static const _kLegacyDbFileName = 'totps';

  /// Creates a new Drift storage instance.
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(onUpgrade: schemaUpgrade);

  /// Stores the given [totp].
  Future<void> addTotp(Totp totp) async {
    await into(totps).insert(
      totp.asDriftTotp,
      mode: .insertOrReplace,
    );
  }

  /// Stores the given [totps].
  Future<void> addTotps(List<Totp> totps) async {
    await batch((batch) {
      batch.insertAll(
        this.totps,
        totps.map((totp) => totp.asDriftTotp),
        mode: .insertOrReplace,
      );
    });
  }

  /// Deletes the TOTP associated to the given [uuid].
  Future<void> deleteTotp(String uuid) async {
    await (delete(totps)..where((totp) => totp.uuid.isValue(uuid))).go();
  }

  /// Deletes the TOTP associated to the given [uuids].
  Future<void> deleteTotps(Iterable<String> uuids) async {
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
  Future<void> replaceTotps(List<Totp> totpsToInsert, DeletedTotpMap tombstonesToInsert) async {
    await totps.deleteAll();
    await removeDeletionMarks([
      for (Totp totp in totpsToInsert) totp.uuid,
    ]);
    await markAsDeleted(tombstonesToInsert);
    await addTotps(totpsToInsert);
  }

  /// Returns all deleted TOTPs.
  Future<DeletedTotpMap> getDeletedTotps() async {
    List<MapEntry<String, DateTime>> tombstones = await (select(deletedTotps)).map((deletedTotp) => MapEntry(deletedTotp.uuid, deletedTotp.deletedAt)).get();
    return Map.fromEntries(tombstones);
  }

  /// Adds the given [tombstones] to the deleted TOTPs table.
  Future<void> markAsDeleted(DeletedTotpMap tombstones) async {
    DeletedTotpMap merged = await getDeletedTotps();

    for (MapEntry<String, DateTime> entry in tombstones.entries) {
      DateTime? current = merged[entry.key];
      if (current == null || current.isBefore(entry.value)) {
        merged[entry.key] = entry.value;
      }
    }

    await batch((batch) {
      batch.deleteAll(deletedTotps);
      batch.insertAll(
        deletedTotps,
        [
          for (MapEntry<String, DateTime> entry in merged.entries)
            _DriftDeletedTotp(uuid: entry.key, deletedAt: entry.value),
        ],
      );
    });

  }

  /// Marks the given [totp] as not deleted.
  Future<void> removeDeletionMarks(List<String> uuids) async {
    await (delete(deletedTotps)..where((deletedTotp) => deletedTotp.uuid.isIn(uuids))).go();
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
    Set<String> operationUuidsToDelete = {};
    Map<String, List<PushOperationResult>> resultsWithErrors = {};
    for (PushOperationResult result in value.result) {
      operationUuidsToDelete.add(result.operationUuid);
      if (!result.success) {
        resultsWithErrors.putIfAbsent(result.totpUuid, () => []).add(result);
      }
    }

    Map<String, PushOperation> pendingOperationsByUuid = {
      for (PushOperation operation in await listPendingBackendPushOperations())
        if (operationUuidsToDelete.contains(operation.uuid)) operation.uuid: operation,
    };

    Map<String, Totp> retrySets = {};
    DeletedTotpMap retryDeletes = {};
    List<_DriftBackendPushOperationError> errors = [];
    for (MapEntry<String, List<PushOperationResult>> entry in resultsWithErrors.entries) {
      for (PushOperationResult result in entry.value) {
        if (!result.errorKind!.isPermanent) {
          PushOperation? operation = pendingOperationsByUuid[result.operationUuid];
          if (operation != null) {
            switch (operation) {
              case SetTotpsPushOperation(:final payload):
                Map<String, dynamic>? totpData = payload[result.totpUuid];
                if (totpData != null) {
                  retrySets[result.totpUuid] = JsonTotp.fromJson(totpData, uuid: result.totpUuid);
                }
                break;
              case DeleteTotpsPushOperation(:final payload):
                int? deletedAt = payload[result.totpUuid];
                if (deletedAt != null) {
                  retryDeletes[result.totpUuid] = DateTime.fromMillisecondsSinceEpoch(deletedAt);
                }
                break;
            }
          }
        }
        errors.add(result.asDriftBackendPushOperationError);
      }
    }

    List<PushOperation> retries = <PushOperation>[
      if (retrySets.isNotEmpty) SetTotpsPushOperation(totps: retrySets.values.toList()),
      if (retryDeletes.isNotEmpty) DeleteTotpsPushOperation(tombstones: retryDeletes),
    ].compacted;

    await batch((batch) {
      batch.deleteWhere(pendingBackendPushOperations, (operation) => operation.uuid.isIn(operationUuidsToDelete));
      batch.insertAll(
        pendingBackendPushOperations,
        [
          for (PushOperation operation in retries) operation.asDriftBackendPushOperation,
        ],
      );
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
    Expression<bool> predicate(BackendPushOperationErrors operation) {
      Expression<bool> errorDetailsPredicate = error.errorDetails == null ? operation.errorDetails.isNull() : operation.errorDetails.isValue(error.errorDetails!);
      return operation.totpUuid.isValue(error.totpUuid) &
          operation.operationUuid.isValue(error.operationUuid) &
          operation.errorKind.isValue(error.errorCode) &
          errorDetailsPredicate &
          operation.createdAt.isValue(error.createdAt);
    }

    await (delete(backendPushOperationErrors)..where(predicate)).go();
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

  /// Opens the connection to the [_kDbFileName] and imports the legacy database if needed.
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      await _importLegacyDatabaseIfNeeded();
      return SqliteUtils.openConnection(_kDbFileName);
    });
  }

  /// Imports the legacy database if needed.
  static Future<void> _importLegacyDatabaseIfNeeded() async {
    File oldDatabase = await _getDatabaseFile(_kLegacyDbFileName);
    if (!await oldDatabase.exists()) {
      return;
    }

    File newDatabase = await _getDatabaseFile(_kDbFileName);

    await _replaceDatabaseFiles(
      sourceMainFile: oldDatabase,
      targetMainFile: newDatabase,
    );

    await _renameLegacyDatabaseFiles(oldDatabase);
  }

  /// Gets the path to the database file.
  static Future<File> _getDatabaseFile(String dbFileName, {bool addDebugModeSuffix = true}) async {
    if (addDebugModeSuffix && kDebugMode) {
      dbFileName += '_debug';
    }
    Directory directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$dbFileName.sqlite');
  }

  /// Replaces the database files.
  static Future<void> _replaceDatabaseFiles({
    required File sourceMainFile,
    required File targetMainFile,
  }) async {
    File sourceWal = File('${sourceMainFile.path}-wal');
    File sourceShm = File('${sourceMainFile.path}-shm');
    File sourceJournal = File('${sourceMainFile.path}-journal');

    File targetWal = File('${targetMainFile.path}-wal');
    File targetShm = File('${targetMainFile.path}-shm');
    File targetJournal = File('${targetMainFile.path}-journal');

    await targetMainFile.parent.create(recursive: true);

    Future<void> deleteIfExists(File file) async {
      if (await file.exists()) {
        await file.delete();
      }
    }

    await deleteIfExists(targetWal);
    await deleteIfExists(targetShm);
    await deleteIfExists(targetJournal);
    await deleteIfExists(targetMainFile);

    await sourceMainFile.copy(targetMainFile.path);
    await _copyIfExists(sourceWal, targetWal);
    await _copyIfExists(sourceShm, targetShm);
    await _copyIfExists(sourceJournal, targetJournal);
  }

  /// Deletes the legacy database files.
  static Future<void> _renameLegacyDatabaseFiles(File legacyMainFile) async {
    Future<void> renameIfExists(File file, {String suffix = '-migrated'}) async {
      if (await file.exists()) {
        await file.rename('${file.path}-$suffix');
      }
    }

    await renameIfExists(legacyMainFile);
    await renameIfExists(File('${legacyMainFile.path}-wal'));
    await renameIfExists(File('${legacyMainFile.path}-shm'));
    await renameIfExists(File('${legacyMainFile.path}-journal'));
  }

  /// Copies the [source] file to the [target] file if it exists.
  static Future<void> _copyIfExists(File source, File target) async {
    if (await source.exists()) {
      await target.parent.create(recursive: true);
      await source.copy(target.path);
    }
  }
}

/// Allows to migrate the database scheme to the latest version.
extension _Migrations on GeneratedDatabase {
  /// Returns the migration strategy.
  OnUpgrade get schemaUpgrade => stepByStep(
    from1To2: (migrator, schema) async {
      await migrator.addColumn(schema.totps, schema.totps.updatedAt);
      await migrator.createTable(schema.deletedTotps);
      await migrator.createTable(schema.pendingBackendPushOperations);
      await migrator.createTable(schema.backendPushOperationErrors);
    },
  );
}
