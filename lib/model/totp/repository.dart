import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/model/backend/synchronization/queue.dart';
import 'package:open_authenticator/model/backup/backup.dart';
import 'package:open_authenticator/model/crypto/derived_key.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/crypto/store.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/image_cache.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/utils/utils.dart';

/// The provider instance.
final AsyncNotifierProvider<TotpRepository, List<Totp>> totpRepositoryProvider = AsyncNotifierProvider.autoDispose<TotpRepository, List<Totp>>(TotpRepository.new);

/// Allows to query, register, update and delete TOTPs.
class TotpRepository extends AsyncNotifier<List<Totp>> {
  @override
  FutureOr<List<Totp>> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final CryptoStore? cryptoStore = await ref.watch(cryptoStoreProvider.future);
    final List<Totp> decrypted = (await database.listTotps()).decrypt(cryptoStore);
    return decrypted.sortCanonically();
  }

  /// Tries to decrypt all TOTPs with the given [cryptoStore].
  /// Returns all newly decrypted TOTPs.
  Future<Set<DecryptedTotp>> tryDecryptAll(CryptoStore? cryptoStore) async {
    final List<Totp> totpsList = await future;
    if (!ref.mounted) {
      return {};
    }
    state = const AsyncLoading();
    final List<Totp> newTotpsList = totpsList.decrypt(cryptoStore);
    final Set<DecryptedTotp> difference = newTotpsList.decryptedTotps.toSet().difference(totpsList.decryptedTotps.toSet());
    if (!ref.mounted) {
      return {};
    }
    state = AsyncData(newTotpsList.sortCanonically());
    return difference;
  }

  /// Adds the given [totp].
  Future<Result<Totp?>> addTotp(
    Totp totp, {
    bool fromNetwork = false,
  }) async {
    final Result<List<Totp>> result = await _addTotps(
      [totp],
      fromNetwork: fromNetwork,
    );
    return result.to((value) => value?.firstOrNull);
  }

  /// Adds the given [totps].
  Future<Result<List<Totp>>> addTotps(
    List<Totp> totps, {
    bool fromNetwork = false,
  }) => _addTotps(
    totps,
    fromNetwork: fromNetwork,
  );

  /// Adds the given [totp].
  Future<Result<List<Totp>>> _addTotps(
    List<Totp> totps, {
    bool fromNetwork = false,
  }) async {
    try {
      final List<Totp> totpsList = await future;
      final AppDatabase database = ref.read(appDatabaseProvider);
      final DeletedTotpMap deletedTotps = await database.getDeletedTotps();
      final List<String> deletedTombstones = [];
      final List<Totp> inserts = List.of(totps);
      for (final Totp totp in totps) {
        final DateTime? deletedAt = deletedTotps[totp.uuid];
        if (deletedAt == null) {
          continue;
        }
        if (deletedAt.isBefore(totp.updatedAt)) {
          deletedTombstones.add(totp.uuid);
        } else {
          inserts.remove(totp);
        }
      }
      if (deletedTombstones.isNotEmpty) {
        await database.removeDeletionMarks(deletedTombstones);
      }
      if (inserts.length == 1) {
        await database.addTotp(inserts.first);
      } else {
        await database.addTotps(inserts);
      }
      final StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .shared && !fromNetwork) {
        _enqueue(
          SetTotpsPushOperation(
            totps: inserts,
          ),
        );
      }
      final CryptoStore? cryptoStore = await ref.read(cryptoStoreProvider.future);
      final List<Totp> decrypted = inserts.decrypt(cryptoStore);
      ref
          .read(totpImageCacheManagerProvider.notifier)
          .fillCache(
            totps: decrypted,
          );
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(totpsList.createMergedList(totps: decrypted));
      return ResultSuccess(value: inserts);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clears all TOTPs and then adds the [totps].
  Future<Result<List<Totp>>> replaceBy(List<Totp> totps, {bool fromNetwork = false}) async {
    try {
      final List<Totp> inserts = List.of(totps);
      final List<String> uuids = inserts.map((totp) => totp.uuid).toList();
      final AppDatabase database = ref.read(appDatabaseProvider);
      final List<Totp> totpsList = await future;
      final DeletedTotpMap tombstonesToInsert = {};
      for (final Totp totp in totpsList) {
        if (!uuids.contains(totp.uuid)) {
          tombstonesToInsert[totp.uuid] = DateTime.now();
        }
      }
      await database.replaceTotps(inserts, tombstonesToInsert);

      final StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .shared && !fromNetwork) {
        _enqueue(
          DeleteTotpsPushOperation(
            tombstones: tombstonesToInsert,
          ),
          andRun: false,
        );
        _enqueue(
          SetTotpsPushOperation(
            totps: inserts,
          ),
        );
      }
      final CryptoStore? cryptoStore = await ref.read(cryptoStoreProvider.future);
      final List<Totp> decrypted = inserts.decrypt(cryptoStore);
      final TotpImageCacheManager totpImageCacheManager = ref.read(totpImageCacheManagerProvider.notifier);
      totpImageCacheManager.deleteCachedImages(tombstonesToInsert.keys);
      totpImageCacheManager.fillCache(totps: decrypted);
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(decrypted.sortCanonically());
      return ResultSuccess(value: inserts);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Updates the [totp].
  Future<Result<Totp?>> updateTotp(
    DecryptedTotp totp, {
    bool fromNetwork = false,
    bool insertIfNonExistent = false,
  }) async {
    final Result<List<Totp>> result = await _updateTotps(
      [totp],
      fromNetwork: fromNetwork,
    );
    return result.to((value) => value?.firstOrNull);
  }

  /// Updates the [totps].
  Future<Result<List<Totp>>> updateTotps(
    List<Totp> totps, {
    bool fromNetwork = false,
  }) async => await _updateTotps(
    totps,
    fromNetwork: fromNetwork,
  );

  /// Updates the [totps].
  Future<Result<List<Totp>>> _updateTotps(
    List<Totp> totps, {
    bool fromNetwork = false,
  }) async {
    try {
      final List<Totp> totpsList = await future;
      final List<String> uuids = totpsList.map((totp) => totp.uuid).toList();
      final AppDatabase database = ref.read(appDatabaseProvider);
      final DeletedTotpMap deletedTotps = await database.getDeletedTotps();
      final List<Totp> updates = List.of(totps);
      final List<String> deletedTombstones = [];
      for (final Totp totp in totps) {
        if (!uuids.contains(totp.uuid)) {
          updates.remove(totp);
        }
        final DateTime? deletedAt = deletedTotps[totp.uuid];
        if (deletedAt == null) {
          continue;
        }
        if (deletedAt.isBefore(totp.updatedAt)) {
          deletedTombstones.add(totp.uuid);
        } else {
          updates.remove(totp);
        }
      }
      if (deletedTombstones.isNotEmpty) {
        await database.removeDeletionMarks(deletedTombstones);
      }
      if (updates.length == 1) {
        await database.updateTotp(updates.first);
      } else {
        await database.updateTotps(updates);
      }
      final StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .shared && !fromNetwork) {
        _enqueue(
          SetTotpsPushOperation(
            totps: updates,
          ),
        );
      }
      final CryptoStore? cryptoStore = await ref.read(cryptoStoreProvider.future);
      final List<Totp> decrypted = updates.decrypt(cryptoStore);
      ref
          .read(totpImageCacheManagerProvider.notifier)
          .fillCache(
            totps: decrypted,
          );
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(totpsList.createMergedList(totps: decrypted));
      return ResultSuccess(value: decrypted);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes the TOTP associated with the given [uuid].
  Future<Result<(String, DateTime)?>> deleteTotp(String uuid, {DateTime? dateTime, bool fromNetwork = false}) async {
    final Result<Map<String, DateTime>> result = await _deleteTotps(
      {uuid: dateTime ?? DateTime.now()},
      fromNetwork: fromNetwork,
    );
    return result.to((value) => value == null || value.isEmpty ? null : (value.keys.first, value.values.first));
  }

  /// Deletes the TOTPs associated with the given [uuids].
  Future<Result<Map<String, DateTime>>> deleteTotps(DeletedTotpMap totps, {bool fromNetwork = false}) async => await _deleteTotps(
    totps,
    fromNetwork: fromNetwork,
  );

  /// Deletes the TOTP associated with the given [uuid].
  Future<Result<Map<String, DateTime>>> _deleteTotps(DeletedTotpMap totps, {bool fromNetwork = false}) async {
    try {
      final List<Totp> totpsList = await future;
      final AppDatabase database = ref.read(appDatabaseProvider);
      final DeletedTotpMap deletes = {};
      final DeletedTotpMap currentlyDeletedTotps = await database.getDeletedTotps();
      for (final MapEntry<String, DateTime> entry in totps.entries) {
        final Totp? totp = totpsList.firstWhereOrNull((totp) => totp.uuid == entry.key);
        if (totp != null && totp.updatedAt.isAfter(entry.value)) {
          continue;
        }
        final DateTime? deletedAt = currentlyDeletedTotps[entry.key];
        if (deletedAt != null && !deletedAt.isBefore(entry.value)) {
          continue;
        }
        deletes[entry.key] = entry.value;
      }
      await database.deleteTotps(deletes.keys);
      await database.markAsDeleted(deletes);
      final StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .shared && !fromNetwork) {
        _enqueue(
          DeleteTotpsPushOperation(
            tombstones: deletes,
          ),
        );
      }
      ref
          .read(totpImageCacheManagerProvider.notifier)
          .deleteCachedImages(
            deletes.keys,
          );
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(
        [
          for (final Totp totp in totpsList)
            if (!deletes.containsKey(totp.uuid)) totp,
        ],
      );
      return ResultSuccess(value: deletes);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Changes the master password.
  /// Please consider doing a backup by passing a [backupPassword], and restore it in case of failure.
  Future<Result<String>> changeMasterPassword(
    String password, {
    String? backupPassword,
    Uint8List? salt,
    bool updateTotps = true,
  }) async {
    try {
      if (backupPassword != null) {
        final Result<Backup> backupResult = await ref.read(backupStoreProvider.notifier).doBackup(backupPassword);
        if (backupResult is! ResultSuccess) {
          return backupResult.to((value) => null);
        }
      }
      final List<Totp> totpsList = await future;
      final CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
      if (updateTotps && currentCryptoStore != null) {
        final CryptoStore newCryptoStore = CryptoStore.fromPassword(password, currentCryptoStore.salt);
        final List<Totp> newTotps = [];
        for (final Totp totp in totpsList) {
          final DecryptedTotp? decryptedTotp = totp.changeEncryptionKey(currentCryptoStore, newCryptoStore);
          newTotps.add(decryptedTotp ?? totp);
        }
        final AppDatabase database = ref.read(appDatabaseProvider);
        await database.replaceTotps(newTotps, {});
        final StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
        if (storageType == .shared) {
          _enqueue(
            SetTotpsPushOperation(
              totps: newTotps,
            ),
          );
        }
      }
      await ref.read(saltProvider.notifier).generateIfNeeded();
      await ref.read(derivedKeyProvider.notifier).updateFromPassword(password);
      return ResultSuccess(value: password);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Enqueues the given [operation].
  void _enqueue(PushOperation operation, {bool andRun = true}) => ref
      .read(pushOperationsQueueProvider.notifier)
      .enqueue(
        operation,
        andRun: andRun,
      );
}

/// Allows to easily decrypt a TOTP list.
extension _DecryptList on List<Totp> {
  /// Sorts the TOTP list.
  List<Totp> sortCanonically() => List.of(this)..sort();

  /// Merges the [totp] to the current TOTP list.
  List<Totp> createMergedList({
    Totp? totp,
    List<Totp>? totps,
    bool sort = true,
  }) {
    final List<Totp> from = [
      ?totp,
      if (totps != null)
        for (final Totp totp in totps) totp,
    ];
    final Set<String> uuids = {
      for (final Totp totp in from) totp.uuid,
    };
    final List<Totp> result = [
      ...from,
      for (final Totp totp in this)
        if (!uuids.contains(totp.uuid)) totp,
    ];
    return sort ? result.sortCanonically() : result;
  }

  /// Decrypts the current list.
  List<Totp> decrypt(CryptoStore? cryptoStore) => [
    for (final Totp totp in this) //
      totp.decrypt(cryptoStore),
  ];

  /// Returns the decrypted TOTPs list.
  List<DecryptedTotp> get decryptedTotps => [
    for (final Totp totp in this)
      if (totp.isDecrypted) totp as DecryptedTotp,
  ];
}
