import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    StorageMigrationDeletedTotpPolicy storageMigrationDeletedTotpPolicy = StorageMigrationDeletedTotpPolicy.ask,
  }) async {
    try {
      if (masterPassword != null) {
        Result<bool> passwordCheckResult = await (await ref.read(passwordVerificationProvider.future)).isPasswordValid(masterPassword);
        if (passwordCheckResult is! ResultSuccess || !(passwordCheckResult as ResultSuccess<bool>).value) {
          throw (passwordCheckResult as ResultError).exception;
        }
      }

      if (value == StorageType.localOnly) {
        super.changeValue(value);
        return const ResultSuccess();
      }

      if (backupPassword != null) {
        Result<Backup> backupResult = await ref.read(backupStoreProvider.notifier).doBackup(backupPassword);
        if (backupResult is! ResultSuccess) {
          throw BackupException();
        }
      }

      AppDatabase database = ref.read(appDatabaseProvider);
      List<String> toDelete = [];
      Result<GetUserTotpsResponse> result = await ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            const GetUserTotpsRequest(),
          );
      if (result is! ResultSuccess<GetUserTotpsResponse>) {
        throw GenericMigrationError();
      }

      GetUserTotpsResponse response = result.value;
      for (Totp totp in response.totps) {
        if (await database.isMarkedAsDeleted(totp.uuid)) {
          switch (storageMigrationDeletedTotpPolicy) {
            case StorageMigrationDeletedTotpPolicy.keep:
              database.removeDeletionMark(totp.uuid);
              break;
            case StorageMigrationDeletedTotpPolicy.delete:
              toDelete.add(totp.uuid);
              break;
            case StorageMigrationDeletedTotpPolicy.ask:
              throw ShouldAskForDifferentDeletedTotpPolicyException();
          }
        }
      }

      List<Totp> currentStorageTotps = await database.listTotps();
      List<Totp> toAdd = [];
      if (masterPassword == null || response.totps.isEmpty) {
        toAdd.addAll(currentStorageTotps);
      } else {
        CryptoStore? currentCryptoStore = ref.read(cryptoStoreProvider).value;
        CryptoStore? newCryptoStore;
        for (Totp totp in response.totps) {
          CryptoStore cryptoStore = await CryptoStore.fromPassword(masterPassword, totp.encryptedData.encryptionSalt);
          if (await totp.encryptedData.canDecryptData(cryptoStore)) {
            newCryptoStore = cryptoStore;
            break;
          }
        }
        newCryptoStore ??= await CryptoStore.fromPassword(masterPassword, response.totps.first.encryptedData.encryptionSalt);

        for (Totp totp in currentStorageTotps) {
          CryptoStore oldCryptoStore;
          if (currentCryptoStore != null && await totp.encryptedData.canDecryptData(currentCryptoStore)) {
            oldCryptoStore = currentCryptoStore;
          } else if (await totp.encryptedData.canDecryptData(newCryptoStore)) {
            oldCryptoStore = newCryptoStore;
          } else {
            oldCryptoStore = await CryptoStore.fromPassword(
              masterPassword,
              totp.encryptedData.encryptionSalt,
            );
          }
          DecryptedTotp? decryptedTotp = await totp.changeEncryptionKey(oldCryptoStore, newCryptoStore);
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
            uuids: toDelete,
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
sealed class StorageMigrationException implements Exception {
  /// The exception code.
  final String code;

  /// Creates a new storage migration exception instance.
  const StorageMigrationException({
    required this.code,
  });
}

/// An generic error occurred.
class GenericMigrationError extends StorageMigrationException {
  /// The error code.
  static const String _code = 'genericError';

  /// Creates a new generic migration error instance.
  GenericMigrationError()
    : super(
        code: _code,
      );

  @override
  String toString() => 'Generic exception occurred';
}

/// Whether we should ask for a different [StorageMigrationDeletedTotpPolicy].
class ShouldAskForDifferentDeletedTotpPolicyException extends StorageMigrationException {
  /// The error code.
  static const String _code = 'shouldAskForDifferentDeletedTotpPolicy';

  /// Creates a new storage migration policy exception instance.
  ShouldAskForDifferentDeletedTotpPolicyException()
    : super(
        code: _code,
      );

  @override
  String toString() => 'Another deleted TOTP policy should be used';
}

/// When we haven't succeeded to do the asked backup.
class BackupException extends StorageMigrationException {
  /// The error code.
  static const String _code = 'backupError';

  /// Creates a new backup exception instance.
  BackupException()
    : super(
        code: _code,
      );

  @override
  String toString() => 'Exception while doing the backup';
}

/// When the provided password don't match the one that has been using on the old storage.
class CurrentStoragePasswordMismatchException extends StorageMigrationException {
  /// The error code.
  static const String _code = 'currentStoragePasswordMismatch';

  /// Creates a new current storage password mismatch exception instance.
  CurrentStoragePasswordMismatchException()
    : super(
        code: _code,
      );

  @override
  String toString() => 'Current storage password is incorrect';
}

/// When there is an error while trying to change the encryption key of the old storage.
class EncryptionKeyChangeFailedError extends StorageMigrationException {
  /// The error code.
  static const String _code = 'encryptionKeyChangeFailed';

  /// Creates a new encryption key change error instance.
  EncryptionKeyChangeFailedError()
    : super(
        code: _code,
      );

  @override
  String toString() => 'Failed to change encryption key';
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
