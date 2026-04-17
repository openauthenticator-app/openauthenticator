import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/model/backend/synchronization/queue.dart';
import 'package:open_authenticator/model/backup.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/password_verification/password_verification.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/result.dart';

/// The storage type settings entry provider.
final storageTypeSettingsEntryProvider = AsyncNotifierProvider.autoDispose<StorageTypeSettingsEntry, StorageType>(StorageTypeSettingsEntry.new);

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
        Result<bool> passwordCheckResult = await (await ref.read(passwordVerificationProvider.future)).isPasswordValid(masterPassword);
        if (passwordCheckResult is! ResultSuccess) {
          throw (passwordCheckResult as ResultError).exception;
        }
        if (!(passwordCheckResult as ResultSuccess<bool>).value) {
          throw _CurrentStoragePasswordMismatchException();
        }
      }

      if (value == .localOnly) {
        super.changeValue(value);
        return const ResultSuccess();
      }

      if (backupPassword != null) {
        Result<Backup> backupResult = await ref.read(backupStoreProvider.notifier).doBackup(backupPassword);
        if (backupResult is! ResultSuccess) {
          throw _BackupException();
        }
      }

      AppDatabase database = ref.read(appDatabaseProvider);
      Result<GetUserTotpsResponse> result = await ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            const GetUserTotpsRequest(),
          );
      if (result is! ResultSuccess<GetUserTotpsResponse>) {
        throw _GetTotpsError();
      }

      GetUserTotpsResponse response = result.value;
      DeletedTotpMap locallyDeletedTotps = await database.getDeletedTotps();
      List<String> tombstonesToRemove = [];
      DeletedTotpMap toDelete = {};
      for (Totp totp in response.totps) {
        DateTime? deletedAt = locallyDeletedTotps[totp.uuid];
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

      if (tombstonesToRemove.isNotEmpty) {
        await database.removeDeletionMarks(tombstonesToRemove);
      }

      List<Totp> currentStorageTotps = await database.listTotps();
      List<Totp> toAdd = [];
      if (masterPassword == null || response.totps.isEmpty) {
        toAdd.addAll(currentStorageTotps);
      } else {
        CryptoStore? currentCryptoStore = ref.read(cryptoStoreProvider).value;
        CryptoStore? newCryptoStore;
        for (Totp totp in response.totps) {
          CryptoStore cryptoStore = CryptoStore.fromPassword(masterPassword, totp.encryptedData.encryptionSalt);
          if (totp.encryptedData.canDecryptData(cryptoStore)) {
            newCryptoStore = cryptoStore;
            break;
          }
        }
        newCryptoStore ??= CryptoStore.fromPassword(masterPassword, response.totps.first.encryptedData.encryptionSalt);

        for (Totp totp in currentStorageTotps) {
          CryptoStore oldCryptoStore;
          if (currentCryptoStore != null && totp.encryptedData.canDecryptData(currentCryptoStore)) {
            oldCryptoStore = currentCryptoStore;
          } else if (totp.encryptedData.canDecryptData(newCryptoStore)) {
            oldCryptoStore = newCryptoStore;
          } else {
            oldCryptoStore = CryptoStore.fromPassword(masterPassword, totp.encryptedData.encryptionSalt);
          }
          DecryptedTotp? decryptedTotp = totp.changeEncryptionKey(oldCryptoStore, newCryptoStore);
          toAdd.add(decryptedTotp ?? totp);
        }
        await ref.read(cryptoStoreProvider.notifier).changeCryptoStore(masterPassword, newCryptoStore: newCryptoStore);
      }

      ref.read(pushOperationsQueueProvider.notifier)
        ..enqueue(
          SetTotpsPushOperation(
            totps: toAdd,
          ),
          andRun: false,
        )
        ..enqueue(
          DeleteTotpsPushOperation(
            tombstones: toDelete,
          ),
        );

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
