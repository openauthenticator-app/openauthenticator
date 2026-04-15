import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/model/backend/synchronization/queue.dart';
import 'package:open_authenticator/model/backup.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/image_cache.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/result.dart';

/// The provider instance.
final totpRepositoryProvider = AsyncNotifierProvider.autoDispose<TotpRepository, List<Totp>>(TotpRepository.new);

/// Allows to query, register, update and delete TOTPs.
class TotpRepository extends AsyncNotifier<List<Totp>> {
  @override
  FutureOr<List<Totp>> build() async {
    AppDatabase database = ref.watch(appDatabaseProvider);
    CryptoStore? cryptoStore = await ref.watch(cryptoStoreProvider.future);
    List<Totp> decrypted = await (await database.listTotps()).decrypt(cryptoStore);
    return decrypted.sortCanonically();
  }

  /// Tries to decrypt all TOTPs with the given [cryptoStore].
  /// Returns all newly decrypted TOTPs.
  Future<Set<DecryptedTotp>> tryDecryptAll(CryptoStore? cryptoStore) async {
    List<Totp> totpsList = await future;
    if (!ref.mounted) {
      return {};
    }
    state = const AsyncLoading();
    List<Totp> newTotpsList = await totpsList.decrypt(cryptoStore);
    Set<DecryptedTotp> difference = newTotpsList.decryptedTotps.toSet().difference(totpsList.decryptedTotps.toSet());
    if (!ref.mounted) {
      return {};
    }
    state = AsyncData(newTotpsList.sortCanonically());
    return difference;
  }

  /// Adds the given [totps].
  Future<Result<Totp>> addTotps(
    List<Totp> totps, {
    bool fromNetwork = false,
  }) => _addTotps(
    totps,
    fromNetwork: fromNetwork,
  );

  /// Adds the given [totp].
  Future<Result<Totp>> addTotp(
    Totp totp, {
    bool fromNetwork = false,
  }) => _addTotps(
    [totp],
    fromNetwork: fromNetwork,
  );

  /// Adds the given [totp].
  Future<Result<Totp>> _addTotps(
    List<Totp> totps, {
    bool fromNetwork = false,
  }) async {
    try {
      List<Totp> totpsList = await future;
      AppDatabase database = ref.read(appDatabaseProvider);
      totps = [
        for (Totp totp in totps)
          if (!(await database.isMarkedAsDeleted(totp.uuid))) totp,
      ];
      if (totps.length == 1) {
        await database.addTotp(totps.first);
      } else {
        await database.addTotps(totps);
      }
      StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .shared && !fromNetwork) {
        _enqueue(
          SetTotpsPushOperation(
            totps: totps,
          ),
        );
      }
      ref.read(totpImageCacheManagerProvider.notifier).fillCache(totps: totps);
      CryptoStore? cryptoStore = await ref.read(cryptoStoreProvider.future);
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(totpsList.createMergedList(totps: await totps.decrypt(cryptoStore)));
      return const ResultSuccess();
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
      List<Totp> totpsList = await future;
      AppDatabase database = ref.read(appDatabaseProvider);
      await database.replaceTotps(totps);
      StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .shared && !fromNetwork) {
        _enqueue(
          DeleteTotpsPushOperation(
            uuids: [
              for (Totp totp in totpsList) totp.uuid,
            ],
          ),
          andRun: false,
        );
        _enqueue(
          SetTotpsPushOperation(
            totps: totps,
          ),
        );
      }
      CryptoStore? cryptoStore = await ref.read(cryptoStoreProvider.future);
      List<Totp> decrypted = await totps.decrypt(cryptoStore);
      await ref.read(totpImageCacheManagerProvider.notifier).fillCache(totps: decrypted);
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(decrypted.sortCanonically());
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Updates the [totp].
  Future<Result<Totp>> updateTotp(
    DecryptedTotp totp, {
    bool fromNetwork = false,
    bool insertIfNonExistent = false,
  }) async => await _updateTotps(
    [totp],
    fromNetwork: fromNetwork,
  );

  /// Updates the [totps].
  Future<Result<Totp>> updateTotps(
    List<Totp> totps, {
    bool fromNetwork = false,
  }) async => await _updateTotps(
    totps,
    fromNetwork: fromNetwork,
  );

  /// Updates the [totps].
  Future<Result<Totp>> _updateTotps(
    List<Totp> totps, {
    bool fromNetwork = false,
  }) async {
    try {
      if (totps.isEmpty) {
        return const ResultSuccess();
      }
      List<Totp> totpsList = await future;
      AppDatabase database = ref.read(appDatabaseProvider);
      if (totps.length > 1) {
        await database.updateTotps(totps);
      } else {
        await database.updateTotp(totps.first);
      }
      StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .shared && !fromNetwork) {
        _enqueue(
          SetTotpsPushOperation(
            totps: totps,
          ),
        );
      }
      CryptoStore? cryptoStore = await ref.read(cryptoStoreProvider.future);
      List<Totp> decrypted = await totps.decrypt(cryptoStore);
      await ref.read(totpImageCacheManagerProvider.notifier).fillCache(totps: decrypted);
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(totpsList.createMergedList(totps: decrypted));
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes the TOTP associated with the given [uuid].
  Future<Result> deleteTotp(String uuid, {bool fromNetwork = false}) async => await _deleteTotps(
    [uuid],
    fromNetwork: fromNetwork,
  );

  /// Deletes the TOTPs associated with the given [uuids].
  Future<Result> deleteTotps(List<String> uuids, {bool fromNetwork = false}) async => await _deleteTotps(
    uuids,
    fromNetwork: fromNetwork,
  );

  /// Deletes the TOTP associated with the given [uuid].
  Future<Result> _deleteTotps(List<String> uuids, {bool fromNetwork = false}) async {
    try {
      List<Totp> totpsList = await future;
      AppDatabase database = ref.read(appDatabaseProvider);
      await database.deleteTotps(uuids);
      await database.markAsDeleted(uuids);
      StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .shared && !fromNetwork) {
        _enqueue(
          DeleteTotpsPushOperation(
            uuids: uuids,
          ),
        );
      }
      ref.read(totpImageCacheManagerProvider.notifier).deleteCachedImages(uuids);
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(
        [
          for (Totp totp in totpsList)
            if (!uuids.contains(totp.uuid)) totp,
        ],
      );
      return const ResultSuccess();
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
      StoredCryptoStore storedCryptoStore = ref.read(cryptoStoreProvider.notifier);
      if (backupPassword != null) {
        Result<Backup> backupResult = await ref.read(backupStoreProvider.notifier).doBackup(backupPassword);
        if (backupResult is! ResultSuccess) {
          return backupResult.to((value) => null);
        }
      }
      List<Totp> totpsList = await future;
      CryptoStore? currentCryptoStore = await storedCryptoStore.future;
      if (updateTotps && currentCryptoStore != null) {
        CryptoStore newCryptoStore = await CryptoStore.fromPassword(password, currentCryptoStore.salt);
        List<Totp> newTotps = [];
        for (Totp totp in totpsList) {
          DecryptedTotp? decryptedTotp = await totp.changeEncryptionKey(currentCryptoStore, newCryptoStore);
          newTotps.add(decryptedTotp ?? totp);
        }
        AppDatabase database = ref.read(appDatabaseProvider);
        await database.replaceTotps(newTotps);
        StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
        if (storageType == .shared) {
          _enqueue(
            SetTotpsPushOperation(
              totps: newTotps,
            ),
          );
        }
        await storedCryptoStore.changeCryptoStore(password, newCryptoStore: newCryptoStore);
      } else {
        await storedCryptoStore.changeCryptoStore(password);
      }
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
  List<Totp> sortCanonically() => List.of(this)
    ..sort((a, b) {
      if (a.isDecrypted) {
        if (b.isDecrypted) {
          int issuersComparison = ((a as DecryptedTotp).issuer ?? '').compareTo((b as DecryptedTotp).issuer ?? '');
          if (issuersComparison != 0) {
            return issuersComparison;
          }
          int labelsComparison = (a.label ?? '').compareTo(b.label ?? '');
          if (labelsComparison != 0) {
            return labelsComparison;
          }
          return a.uuid.compareTo(b.uuid);
        }
        return -1;
      }
      if (b.isDecrypted) {
        return 1;
      }
      return a.uuid.compareTo(b.uuid);
    });

  /// Merges the [totp] to the current TOTP list.
  List<Totp> createMergedList({
    Totp? totp,
    List<Totp>? totps,
    bool sort = true,
  }) {
    List<Totp> from = [
      ?totp,
      if (totps != null)
        for (Totp totp in totps) totp,
    ];
    Set<String> uuids = {
      for (Totp totp in from) totp.uuid,
    };
    List<Totp> result = [
      ...from,
      for (Totp totp in this)
        if (!uuids.contains(totp.uuid)) totp,
    ];
    return sort ? result.sortCanonically() : result;
  }

  /// Decrypts the current list.
  Future<List<Totp>> decrypt(CryptoStore? cryptoStore) async => [
    for (Totp totp in this) //
      await totp.decrypt(cryptoStore),
  ];

  /// Returns the decrypted TOTPs list.
  List<DecryptedTotp> get decryptedTotps => [
    for (Totp totp in this)
      if (totp.isDecrypted) totp as DecryptedTotp,
  ];
}
