import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/core/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/core/backend/synchronization/queue.dart';
import 'package:open_authenticator/core/backup/backup.dart';
import 'package:open_authenticator/core/crypto/derived_key.dart';
import 'package:open_authenticator/core/crypto/salt.dart';
import 'package:open_authenticator/core/crypto/store.dart';
import 'package:open_authenticator/core/database/database.dart';
import 'package:open_authenticator/core/settings/storage_type.dart';
import 'package:open_authenticator/core/totp/decrypted.dart';
import 'package:open_authenticator/core/totp/image_cache.dart';
import 'package:open_authenticator/core/totp/totp.dart';
import 'package:open_authenticator/core/totp/undecryptable.dart';
import 'package:open_authenticator/utils/result/result.dart';

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

  /// Adds one TOTP.
  Future<Result<Totp?>> addTotp(Totp totp, {bool fromNetwork = false}) async => (await addTotps([totp], fromNetwork: fromNetwork)).to((value) => value?.firstOrNull);

  /// Adds the given TOTPs.
  Future<Result<List<Totp>>> addTotps(List<Totp> totps, {bool fromNetwork = false}) => _save(totps, fromNetwork: fromNetwork);

  /// Replaces the entire vault and records deletions.
  Future<Result<List<Totp>>> replaceBy(List<Totp> totps, {bool fromNetwork = false}) => _save(totps, replace: true, fromNetwork: fromNetwork);

  /// Updates an existing TOTP.
  Future<Result<Totp?>> updateTotp(DecryptedTotp totp, {bool fromNetwork = false}) async => (await updateTotps([totp], fromNetwork: fromNetwork)).to((value) => value?.firstOrNull);

  /// Updates existing TOTPs.
  Future<Result<List<Totp>>> updateTotps(List<Totp> totps, {bool fromNetwork = false}) => _save(totps, updateOnly: true, fromNetwork: fromNetwork);

  Future<Result<List<Totp>>> _save(List<Totp> totps, {bool replace = false, bool updateOnly = false, bool fromNetwork = false}) async {
    if (!replace && totps.isEmpty) {
      return const ResultSuccess(value: []);
    }
    try {
      await future;
      final AppDatabase database = ref.read(appDatabaseProvider);
      final bool enqueue = !fromNetwork && await ref.read(storageTypeSettingsEntryProvider.future) == StorageType.shared;
      final CryptoStore? cryptoStore = await ref.read(cryptoStoreProvider.future);
      final (List<Totp> saved, DeletedTotpMap removed) = await database.saveTotps(totps, replace: replace, updateOnly: updateOnly, fromNetwork: fromNetwork, enqueue: enqueue);
      if (enqueue && (saved.isNotEmpty || removed.isNotEmpty)) {
        _notifySync();
      }
      final List<Totp> decrypted = saved.decrypt(cryptoStore);
      final List<Totp> current = state.value ?? await future;
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(replace ? decrypted.sortCanonically() : current.createMergedList(decrypted));
      final TotpImageCacheManager cache = ref.read(totpImageCacheManagerProvider.notifier);
      if (removed.isNotEmpty) {
        unawaited(cache.deleteCachedImages(removed.keys));
      }
      if (decrypted.isNotEmpty) {
        unawaited(cache.fillCache(totps: decrypted));
      }
      return ResultSuccess(value: decrypted);
    } catch (ex, stackTrace) {
      return ResultError(exception: ex, stackTrace: stackTrace);
    }
  }

  /// Deletes a TOTP by UUID.
  Future<Result<(String, DateTime)?>> deleteTotp(String uuid, {DateTime? dateTime, bool fromNetwork = false}) async =>
      (await deleteTotps({uuid: dateTime ?? DateTime.now()}, fromNetwork: fromNetwork)).to((value) => value == null || value.isEmpty ? null : (value.keys.first, value.values.first));

  /// Applies the given deletion timestamps.
  Future<Result<DeletedTotpMap>> deleteTotps(DeletedTotpMap totps, {bool fromNetwork = false}) async {
    if (totps.isEmpty) {
      return const ResultSuccess(value: {});
    }
    try {
      await future;
      final bool enqueue = !fromNetwork && await ref.read(storageTypeSettingsEntryProvider.future) == StorageType.shared;
      final DeletedTotpMap deletes = await ref.read(appDatabaseProvider).deleteTotps(totps, enqueue: enqueue);
      if (deletes.isNotEmpty) {
        if (enqueue) {
          _notifySync();
        }
        final List<Totp> current = state.value ?? await future;
        if (!ref.mounted) {
          return const ResultCancelled();
        }
        state = AsyncData(current.where((totp) => !deletes.containsKey(totp.uuid)).toList());
        unawaited(ref.read(totpImageCacheManagerProvider.notifier).deleteCachedImages(deletes.keys));
      }
      return ResultSuccess(value: deletes);
    } catch (ex, stackTrace) {
      return ResultError(exception: ex, stackTrace: stackTrace);
    }
  }

  void _notifySync() => ref.read(synchronizationControllerProvider.notifier).notifyLocalChange();

  /// Changes the master password.
  /// Please consider doing a backup by passing a [backupPassword], and restore it in case of failure.
  Future<Result<String>> changeMasterPassword(
    String password, {
    String? backupPassword,
    bool updateTotps = true,
  }) async {
    try {
      if (backupPassword != null) {
        final Result<Backup> backupResult = await ref.read(backupStoreProvider.notifier).doBackup(backupPassword);
        if (backupResult is! ResultSuccess) {
          return backupResult.to((value) => null);
        }
      }
      await future;
      final CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
      final AppDatabase database = ref.read(appDatabaseProvider);
      final enqueue = await ref.read(storageTypeSettingsEntryProvider.future) == StorageType.shared;
      await ref.read(saltProvider.notifier).generateIfNeeded();
      final DerivedKeyNotifier keyNotifier = ref.read(derivedKeyProvider.notifier);
      if (updateTotps && currentCryptoStore != null) {
        final CryptoStore newStore = await CryptoStore.fromPasswordInIsolate(password, currentCryptoStore.salt);
        await database.transaction(() async {
          final List<Totp> records = await database.listTotps();
          final List<DecryptedTotp> updated = [];
          final List<String> undecryptable = [];
          for (final Totp totp in records) {
            final DecryptedTotp? decryptedTotp = totp.changeEncryptionKey(currentCryptoStore, newStore);
            if (decryptedTotp == null) {
              undecryptable.add(totp.uuid);
            } else {
              updated.add(decryptedTotp);
            }
          }
          if (undecryptable.isNotEmpty) {
            throw UndecryptableTotpsException(undecryptable);
          }
          await database.addTotps(updated);
          if (enqueue && updated.isNotEmpty) {
            await database.addPendingBackendPushOperation(SetTotpsPushOperation(totps: updated));
          }
          await keyNotifier.updateFromPassword(password, derivedStore: newStore);
        });
        if (enqueue) {
          _notifySync();
        }
      } else {
        await keyNotifier.updateFromPassword(password);
      }
      return ResultSuccess(value: password);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Allows to easily decrypt a TOTP list.
extension _DecryptList on List<Totp> {
  /// Sorts the TOTP list.
  List<Totp> sortCanonically() => List.of(this)..sort();

  /// Merges persisted changes into the displayed list.
  List<Totp> createMergedList(List<Totp> changes) {
    final Set<String> uuids = changes.map((totp) => totp.uuid).toSet();
    return [...changes, ...where((totp) => !uuids.contains(totp.uuid))]..sort();
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
