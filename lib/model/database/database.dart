import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/model/backend/synchronization/push/result.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/database/database.steps.dart';
import 'package:open_authenticator/model/totp/algorithm.dart';
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/drift.dart';
import 'package:open_authenticator/utils/json.dart';
import 'package:open_authenticator/utils/sqlite.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';
part 'extensions.dart';
part 'tables.dart';

/// A map of deleted TOTPs.
typedef DeletedTotpMap = Map<String, DateTime>;

/// The app database provider.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase storage = AppDatabase();
  ref.onDispose(storage.close);
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

  /// Creates a new Drift storage instance using the given [executor].
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

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

  /// Deletes the TOTPs associated to the [tombstones] keys and marks them as deleted.
  Future<void> deleteTotps(DeletedTotpMap tombstones) => transaction(() async {
    await (delete(totps)..where((totp) => totp.uuid.isIn(tombstones.keys))).go();
    await markAsDeleted(tombstones);
  });

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
          for (final Totp totp in totps) totp.asDriftTotp,
        ],
      );
    });
  }

  /// Lists all TOTPs.
  Future<List<Totp>> listTotps() => select(totps).map((totp) => totp.asTotp).get();

  /// Replace all current TOTPs by [totpsToInsert].
  Future<void> replaceTotps(List<Totp> totpsToInsert, DeletedTotpMap tombstonesToInsert) => transaction(() async {
    await totps.deleteAll();
    await removeDeletionMarks([
      for (final Totp totp in totpsToInsert) totp.uuid,
    ]);
    await markAsDeleted(tombstonesToInsert);
    await addTotps(totpsToInsert);
  });

  /// Returns all deleted TOTPs.
  Future<DeletedTotpMap> getDeletedTotps() async {
    final List<MapEntry<String, DateTime>> tombstones = await (select(deletedTotps)).map((deletedTotp) => MapEntry(deletedTotp.uuid, deletedTotp.deletedAt)).get();
    return Map.fromEntries(tombstones);
  }

  /// Adds the given [tombstones] to the deleted TOTPs table. Existing tombstones are only replaced by newer ones.
  Future<void> markAsDeleted(DeletedTotpMap tombstones) async {
    if (tombstones.isEmpty) {
      return;
    }
    await transaction(() async {
      final List<_DriftDeletedTotp> existing = await (select(deletedTotps)..where((deletedTotp) => deletedTotp.uuid.isIn(tombstones.keys))).get();
      final DeletedTotpMap current = {
        for (final _DriftDeletedTotp deletedTotp in existing) deletedTotp.uuid: deletedTotp.deletedAt,
      };
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          deletedTotps,
          [
            for (final MapEntry<String, DateTime> entry in tombstones.entries)
              if (current[entry.key]?.isBefore(entry.value) ?? true)
                _DriftDeletedTotp(
                  uuid: entry.key,
                  deletedAt: entry.value,
                ),
          ],
        );
      });
    });
  }

  /// Marks the given [totp] as not deleted.
  Future<void> removeDeletionMarks(List<String> uuids) async {
    await (delete(deletedTotps)..where((deletedTotp) => deletedTotp.uuid.isIn(uuids))).go();
  }

  /// Selects the pending backend push operations.
  Selectable<PushOperation> _selectPendingBackendPushOperations() {
    final SimpleSelectStatement<$PendingBackendPushOperationsTable, _DriftBackendPushOperation> operations = select(pendingBackendPushOperations)
      ..orderBy([
        (table) => OrderingTerm.desc(table.createdAt),
        (table) => OrderingTerm.asc(table.kind),
        (table) => OrderingTerm.asc(table.uuid),
      ]);
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
          for (final PushOperation operation in operations) operation.asDriftBackendPushOperation,
        ],
      );
    });
  }

  /// Applies the given push response.
  Future<void> applyPushResponse(SynchronizationPushResponse value) async {
    final Set<String> operationUuidsToDelete = {};
    final Map<String, List<PushOperationResult>> resultsWithErrors = {};
    for (final PushOperationResult result in value.result) {
      operationUuidsToDelete.add(result.operationUuid);
      if (!result.success) {
        resultsWithErrors.putIfAbsent(result.totpUuid, () => []).add(result);
      }
    }

    final Map<String, PushOperation> pendingOperationsByUuid = {
      for (final PushOperation operation in await listPendingBackendPushOperations())
        if (operationUuidsToDelete.contains(operation.uuid)) operation.uuid: operation,
    };

    final Map<String, Totp> retrySets = {};
    final DeletedTotpMap retryDeletes = {};
    final List<_DriftBackendPushOperationError> errors = [];
    for (final MapEntry<String, List<PushOperationResult>> entry in resultsWithErrors.entries) {
      for (final PushOperationResult result in entry.value) {
        if (!result.errorKind!.isPermanent) {
          final PushOperation? operation = pendingOperationsByUuid[result.operationUuid];
          if (operation != null) {
            switch (operation) {
              case SetTotpsPushOperation(:final JsonMap payload):
                final JsonMap? totpData = payload[result.totpUuid];
                if (totpData != null) {
                  retrySets[result.totpUuid] = JsonTotp.fromJson(totpData, uuid: result.totpUuid);
                }
                break;
              case DeleteTotpsPushOperation(:final Map<String, int> payload):
                final int? deletedAt = payload[result.totpUuid];
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

    final List<PushOperation> retries = <PushOperation>[
      if (retrySets.isNotEmpty) SetTotpsPushOperation(totps: retrySets.values.toList()),
      if (retryDeletes.isNotEmpty) DeleteTotpsPushOperation(tombstones: retryDeletes),
    ].compacted;

    await batch((batch) {
      batch.deleteWhere(pendingBackendPushOperations, (operation) => operation.uuid.isIn(operationUuidsToDelete));
      batch.insertAll(
        pendingBackendPushOperations,
        [
          for (final PushOperation operation in retries) operation.asDriftBackendPushOperation,
        ],
      );
      batch.insertAll(backendPushOperationErrors, errors);
    });
  }

  /// Selects the backend push operation errors.
  Selectable<PushOperationError> _selectBackendPushOperationErrors() {
    final SimpleSelectStatement<$BackendPushOperationErrorsTable, _DriftBackendPushOperationError> operations = select(backendPushOperationErrors)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
    return operations.map((operation) => operation.asBackendPushOperationResult as PushOperationError);
  }

  /// Returns the stream of backend push operation errors.
  Stream<List<PushOperationError>> watchBackendPushOperationErrors() => _selectBackendPushOperationErrors().watch();

  /// Adds a new backend push operation error.
  Future<void> deleteBackendPushOperationError(PushOperationError error) async {
    assert(!error.success, 'Cannot delete a successful operation.');
    Expression<bool> predicate(BackendPushOperationErrors operation) {
      final Expression<bool> errorDetailsPredicate = error.errorDetails == null ? operation.errorDetails.isNull() : operation.errorDetails.isValue(error.errorDetails!);
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
  static QueryExecutor _openConnection() => LazyDatabase(() async {
    await _importLegacyDatabaseIfNeeded();
    return SqliteUtils.openConnection(_kDbFileName);
  });

  /// Imports the legacy database if needed.
  static Future<void> _importLegacyDatabaseIfNeeded() async {
    final File oldDatabase = await _getDatabaseFile(_kLegacyDbFileName);
    if (!await oldDatabase.exists()) {
      return;
    }

    final File newDatabase = await _getDatabaseFile(_kDbFileName);

    await _replaceDatabaseFiles(
      sourceMainFile: oldDatabase,
      targetMainFile: newDatabase,
    );

    await _renameLegacyDatabaseFiles(oldDatabase);
  }

  /// Gets the path to the database file.
  static Future<File> _getDatabaseFile(String dbFileName) async {
    final Directory directory = await getApplicationSupportDirectory();
    return File('${directory.path}/${SqliteUtils.getDbFileName(dbFileName)}.sqlite');
  }

  /// Replaces the database files.
  static Future<void> _replaceDatabaseFiles({
    required File sourceMainFile,
    required File targetMainFile,
  }) async {
    final File sourceWal = File('${sourceMainFile.path}-wal');
    final File sourceShm = File('${sourceMainFile.path}-shm');
    final File sourceJournal = File('${sourceMainFile.path}-journal');

    final File targetWal = File('${targetMainFile.path}-wal');
    final File targetShm = File('${targetMainFile.path}-shm');
    final File targetJournal = File('${targetMainFile.path}-journal');

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

  /// Renames the legacy database files, so that they're not imported again.
  static Future<void> _renameLegacyDatabaseFiles(File legacyMainFile) async {
    Future<void> renameIfExists(File file) async {
      if (await file.exists()) {
        await file.rename('${file.path}-migrated');
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
