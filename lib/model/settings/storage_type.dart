import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/model/backup/backup.dart';
import 'package:open_authenticator/model/crypto/derived_key.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/crypto/store.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/password_verification/password_verification.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/result/result.dart';

/// The storage type settings entry provider.
final AsyncNotifierProvider<StorageTypeSettingsEntry, StorageType> storageTypeSettingsEntryProvider = AsyncNotifierProvider.autoDispose<StorageTypeSettingsEntry, StorageType>(
  StorageTypeSettingsEntry.new,
);

/// A settings entry that allows to get and set the storage type.
class StorageTypeSettingsEntry extends EnumSettingsEntry<StorageType> {
  /// Creates a new storage type settings entry instance.
  StorageTypeSettingsEntry()
    : super(
        key: 'storageType',
        defaultValue: StorageType.localOnly,
      );

  @override
  @protected
  List<StorageType> get values => StorageType.values;

  @override
  Future<Result> changeValue(
    StorageType value, {
    String? masterPassword,
    String? backupPassword,
    StorageMigrationDeletedTotpPolicy storageMigrationDeletedTotpPolicy = .ask,
  }) async {
    try {
      if (masterPassword != null) {
        final Result<bool> passwordCheckResult = await (await ref.read(passwordVerificationProvider.future)).isPasswordValid(masterPassword);
        switch (passwordCheckResult) {
          case ResultError(:final exception, :final stackTrace):
            Error.throwWithStackTrace(exception, stackTrace);
          case ResultSuccess(value: true):
            break;
          default:
            throw _CurrentStoragePasswordMismatchException();
        }
      }

      if (value == .localOnly) {
        await super.changeValue(value);
        return const ResultSuccess();
      }

      if (backupPassword != null) {
        final Result<Backup> backupResult = await ref.read(backupStoreProvider.notifier).doBackup(backupPassword);
        if (backupResult is! ResultSuccess) {
          throw _BackupException();
        }
      }

      final AppDatabase database = ref.read(appDatabaseProvider);
      final Result<GetUserTotpsResponse> result = await ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            const GetUserTotpsRequest(),
          );
      if (result is! ResultSuccess<GetUserTotpsResponse>) {
        throw _GetTotpsError();
      }

      final GetUserTotpsResponse response = result.value;
      final DeletedTotpMap locallyDeletedTotps = await database.getDeletedTotps();
      final List<String> tombstonesToRemove = [];
      final DeletedTotpMap toDelete = {};
      for (final Totp totp in response.totps) {
        final DateTime? deletedAt = locallyDeletedTotps[totp.uuid];
        if (deletedAt != null) {
          switch (storageMigrationDeletedTotpPolicy) {
            case .keep:
              tombstonesToRemove.add(totp.uuid);
              break;
            case .delete:
              toDelete[totp.uuid] = deletedAt;
              break;
            case .ask:
              throw ShouldAskForDifferentDeletedTotpPolicyException();
          }
        }
      }

      final List<Totp> currentStorageTotps = await database.listTotps();
      final List<Totp> toAdd = [];
      CryptoStore? newCryptoStore;
      if (masterPassword == null || response.totps.isEmpty) {
        if (masterPassword == null && response.totps.isNotEmpty && currentStorageTotps.isNotEmpty) {
          final CryptoStore? current = await ref.read(cryptoStoreProvider.future);
          if (current == null || !response.totps.any((totp) => totp.encryptedData.canDecryptData(current))) {
            throw _RemoteStoragePasswordMismatchException();
          }
        }
        toAdd.addAll(currentStorageTotps);
      } else {
        // Key derivation is expensive, so we only do it once per salt.
        final Map<Salt, CryptoStore> cryptoStores = {};
        Future<CryptoStore> cryptoStoreFor(Salt salt) async => cryptoStores[salt] ??= await CryptoStore.fromPasswordInIsolate(masterPassword, salt);

        for (final Totp totp in response.totps) {
          final CryptoStore cryptoStore = await cryptoStoreFor(totp.encryptedData.encryptionSalt);
          if (totp.encryptedData.canDecryptData(cryptoStore)) {
            newCryptoStore = cryptoStore;
            break;
          }
        }
        if (newCryptoStore == null) {
          // The remote TOTPs have been encrypted using another password. Using the current one would mix up keys.
          throw _RemoteStoragePasswordMismatchException();
        }

        final CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
        for (final Totp totp in currentStorageTotps) {
          final CryptoStore oldCryptoStore = currentCryptoStore != null && totp.encryptedData.canDecryptData(currentCryptoStore)
              ? currentCryptoStore
              : await cryptoStoreFor(totp.encryptedData.encryptionSalt);
          toAdd.add(totp.changeEncryptionKey(oldCryptoStore, newCryptoStore) ?? (throw _CurrentStoragePasswordMismatchException()));
        }
      }

      final Salt? previousSalt = await ref.read(saltProvider.future);
      await database.transaction(() async {
        await database.addTotps(toAdd);
        if (tombstonesToRemove.isNotEmpty) {
          await database.removeDeletionMarks(tombstonesToRemove);
        }
        if (toAdd.isNotEmpty) {
          await database.addPendingBackendPushOperation(SetTotpsPushOperation(totps: toAdd));
        }
        if (toDelete.isNotEmpty) {
          await database.addPendingBackendPushOperation(DeleteTotpsPushOperation(tombstones: toDelete));
        }
        if (newCryptoStore case final store?) {
          final SaltNotifier salts = ref.read(saltProvider.notifier);
          if (previousSalt != store.salt) {
            await salts.changeSalt(store.salt);
          }
          try {
            await ref.read(derivedKeyProvider.notifier).updateFromPassword(masterPassword!, derivedStore: store);
          } catch (_) {
            if (previousSalt != store.salt) {
              await salts.changeSalt(previousSalt);
            }
            rethrow;
          }
        }
      });

      await super.changeValue(value);

      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Contains all storage types.
enum StorageType {
  /// Local storage, using Drift.
  localOnly,

  /// Local storage and online storage.
  shared,
}

/// Allows to return various results from the storage migration.
sealed class _StorageMigrationException extends LocalizableException {
  /// Creates a new storage migration exception instance.
  _StorageMigrationException({
    String? localizedErrorMessage,
  }) : super(
         localizedErrorMessage: localizedErrorMessage ?? translations.error.storageMigration.generic,
       );
}

/// Thrown when we're not able to get the user TOTPs.
class _GetTotpsError extends _StorageMigrationException {
  /// Creates a new generic migration error instance.
  _GetTotpsError()
    : super(
        localizedErrorMessage: translations.error.storageMigration.getTotps,
      );
}

/// Whether we should ask for a different [StorageMigrationDeletedTotpPolicy].
class ShouldAskForDifferentDeletedTotpPolicyException extends _StorageMigrationException {
  /// Creates a new storage migration policy exception instance.
  ShouldAskForDifferentDeletedTotpPolicyException()
    : super(
        localizedErrorMessage: translations.error.storageMigration.anotherDeletedTotpPolicyShouldBeUsed,
      );
}

/// When we haven't succeeded to do the asked backup.
class _BackupException extends _StorageMigrationException {
  /// Creates a new backup exception instance.
  _BackupException()
    : super(
        localizedErrorMessage: translations.error.storageMigration.backupError,
      );
}

/// When the provided password cannot decrypt the TOTPs stored online.
class _RemoteStoragePasswordMismatchException extends _StorageMigrationException {
  /// Creates a new remote storage password mismatch exception instance.
  _RemoteStoragePasswordMismatchException()
    : super(
        localizedErrorMessage: translations.error.storageMigration.remoteStoragePasswordMismatch,
      );
}

/// When the provided password don't match the one that has been using on the old storage.
class _CurrentStoragePasswordMismatchException extends _StorageMigrationException {
  /// Creates a new current storage password mismatch exception instance.
  _CurrentStoragePasswordMismatchException()
    : super(
        localizedErrorMessage: translations.error.storageMigration.currentStoragePasswordMismatch,
      );
}

/// Allows to control the behavior when a TOTP has locally been deleted, but not on a different storage.
enum StorageMigrationDeletedTotpPolicy {
  /// Whether we should keep the TOTPs.
  keep,

  /// Whether we should delete the TOTPs.
  delete,

  /// Whether we should return and ask for deletion.
  ask,
}
