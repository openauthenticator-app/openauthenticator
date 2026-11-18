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
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(onUpgrade: (migrator, from, to) => transaction(() => schemaUpgrade(migrator, from, to)));

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

  /// Applies data, tombstones and their outgoing operations in one transaction.
  Future<(List<Totp>, DeletedTotpMap)> saveTotps(List<Totp> input, {bool replace = false, bool updateOnly = false, bool fromNetwork = false, bool enqueue = false}) => transaction(() async {
    final Set<String> ids = input.map((totp) => totp.uuid).toSet();
    final Map<String, DateTime> existing = await _activeTimestamps(replace ? null : ids);
    final DeletedTotpMap deleted = await getDeletedTotps(ids);
    final saved = <Totp>[];
    for (final totp in input) {
      final DateTime? active = existing[totp.uuid];
      final DateTime? tombstone = deleted[totp.uuid];
      if (!replace && ((updateOnly && active == null) || (fromNetwork && active != null && active.isAfter(totp.updatedAt)) || (tombstone != null && !tombstone.isBefore(totp.updatedAt)))) {
        continue;
      }
      saved.add(totp);
    }
    final removed = <String, DateTime>{};
    if (replace) {
      final Set<String> retained = saved.map((totp) => totp.uuid).toSet();
      final now = DateTime.now();
      for (final String uuid in existing.keys.where((uuid) => !retained.contains(uuid))) {
        removed[uuid] = now;
      }
      await replaceTotps(saved, removed);
    } else if (saved.isNotEmpty) {
      await removeDeletionMarks([
        for (final totp in saved)
          if (deleted.containsKey(totp.uuid)) totp.uuid,
      ]);
      await addTotps(saved);
    }
    if (enqueue) {
      if (removed.isNotEmpty) {
        await addPendingBackendPushOperation(DeleteTotpsPushOperation(tombstones: removed));
      }
      if (saved.isNotEmpty) {
        await addPendingBackendPushOperation(SetTotpsPushOperation(totps: saved));
      }
    }
    return (saved, removed);
  });

  /// Deletes entries that have not been edited since the requested timestamp.
  Future<DeletedTotpMap> deleteTotps(DeletedTotpMap requested, {bool enqueue = false}) => transaction(() async {
    final Map<String, DateTime> active = await _activeTimestamps(requested.keys);
    final DeletedTotpMap deleted = await getDeletedTotps(requested.keys);
    final Map<String, DateTime> accepted = {
      for (final entry in requested.entries)
        if (!(active[entry.key]?.isAfter(entry.value) ?? false) && (deleted[entry.key]?.isBefore(entry.value) ?? true)) entry.key: entry.value,
    };
    if (accepted.isNotEmpty) {
      await (delete(totps)..where((totp) => totp.uuid.isIn(accepted.keys))).go();
      await markAsDeleted(accepted);
      if (enqueue) {
        await addPendingBackendPushOperation(DeleteTotpsPushOperation(tombstones: accepted));
      }
    }
    return accepted;
  });

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

  Future<Map<String, DateTime>> _activeTimestamps(Iterable<String>? ids) async {
    final JoinedSelectStatement<$TotpsTable, _DriftTotp> query = selectOnly(totps)..addColumns([totps.uuid, totps.updatedAt]);
    if (ids != null) {
      query.where(totps.uuid.isIn(ids));
    }
    return {
      for (final TypedResult row in await query.get()) row.read(totps.uuid)!: DateTime.fromMillisecondsSinceEpoch(row.read(totps.updatedAt)!),
    };
  }

  /// Returns deletion timestamps for the requested UUIDs, or the entire table.
  Future<DeletedTotpMap> getDeletedTotps([Iterable<String>? ids]) async {
    final SimpleSelectStatement<$DeletedTotpsTable, _DriftDeletedTotp> query = select(deletedTotps);
    if (ids != null) {
      query.where((row) => row.uuid.isIn(ids));
    }
    return {for (final _DriftDeletedTotp row in await query.get()) row.uuid: row.deletedAt};
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
        (table) => OrderingTerm.desc(table.sequence),
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

  /// Reads and compacts a single database snapshot, preserving insertion order.
  Future<List<PushOperation>> compactPendingOperations() => transaction(() async {
    final List<PushOperation> operations = await listPendingBackendPushOperations();
    final List<PushOperation> compacted = operations.compacted;
    final Map<String, PushOperation> retained = {for (final operation in compacted) operation.uuid: operation};
    for (final operation in operations) {
      final PushOperation? remaining = retained[operation.uuid];
      if (remaining == null) {
        await _writePendingPayload(operation.uuid, {});
      } else if (remaining.payload.length != operation.payload.length) {
        await _writePendingPayload(operation.uuid, remaining.payload);
      }
    }
    return compacted;
  });

  Future<void> _writePendingPayload(String uuid, JsonMap payload) async {
    if (payload.isEmpty) {
      await (delete(pendingBackendPushOperations)..where((row) => row.uuid.equals(uuid))).go();
    } else {
      await (update(pendingBackendPushOperations)..where((row) => row.uuid.equals(uuid))).write(
        PendingBackendPushOperationsCompanion(jsonPayload: Value(jsonEncode(payload))),
      );
    }
  }

  /// Keeps transient failures in their original queue position, behind newer edits.
  Future<void> applyPushResponse(SynchronizationPushResponse response) => transaction(() async {
    final results = <String, List<PushOperationResult>>{};
    for (final PushOperationResult result in response.result) {
      (results[result.operationUuid] ??= []).add(result);
    }
    for (final MapEntry<String, List<PushOperationResult>> entry in results.entries) {
      final _DriftBackendPushOperation? row = await (select(pendingBackendPushOperations)..where((row) => row.uuid.equals(entry.key))).getSingleOrNull();
      if (row == null) {
        continue;
      }
      final JsonMap payload = decodeJsonMap(row.jsonPayload);
      for (final PushOperationResult result in entry.value) {
        if (result.success || result.errorKind!.isPermanent) {
          payload.remove(result.totpUuid);
        }
        if (!result.success) {
          await into(backendPushOperationErrors).insert(result.asDriftBackendPushOperationError);
        }
      }
      await _writePendingPayload(entry.key, payload);
    }
  });

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
    from2To3: (migrator, schema) async {
      await customStatement('UPDATE totps SET updated_at = updated_at * 1000');
      await customStatement('UPDATE totps SET validity = NULL WHERE validity <= 0 OR validity > 2147483647');
      await customStatement('UPDATE totps SET digits = NULL WHERE digits < 4 OR digits > 15');
      await customStatement('ALTER TABLE deleted_totps RENAME TO deleted_totps_v2');
      await migrator.createTable(schema.deletedTotps);
      await customStatement('INSERT INTO deleted_totps (uuid, deleted_at) SELECT uuid, deleted_at * 1000 FROM deleted_totps_v2');
      await customStatement('DROP TABLE deleted_totps_v2');
      await customStatement('ALTER TABLE pending_backend_push_operations RENAME TO pending_v2');
      await migrator.createTable(schema.pendingBackendPushOperations);
      await customStatement(
        'INSERT INTO pending_backend_push_operations (uuid, kind, json_payload, created_at) '
        'SELECT uuid, kind, json_payload, created_at * 1000 FROM pending_v2 ORDER BY rowid',
      );
      await customStatement('DROP TABLE pending_v2');
    },
  );
}
