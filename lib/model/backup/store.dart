part of 'backup.dart';

/// The backup store provider.
final backupStoreProvider = AsyncNotifierProvider.autoDispose<BackupStore, List<BackupPath>>(BackupStore.new);

/// Contains all backups.
class BackupStore extends AsyncNotifier<List<BackupPath>> {
  @override
  FutureOr<List<BackupPath>> build() async {
    List<BackupPath> result = [];
    Directory directory = await BackupPath.getBackupsDirectory();
    if (!directory.existsSync()) {
      return result;
    }
    for (FileSystemEntity entity in directory.listSync(followLinks: false)) {
      BackupPath? path = BackupPath.fromPath(path: entity.path);
      if (path != null) {
        result.add(path);
      }
    }
    return result..sort();
  }

  /// Restores the [backupPath] with the given [password].
  Future<Result<Backup>> restoreBackup(BackupPath backupPath, String password) async {
    KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
      if (currentCryptoStore == null) {
        throw _CryptoError();
      }
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      Backup backup = backupPath.read(currentCryptoStore, password);
      Result restoreResult = await backup.restore(ref.read(totpRepositoryProvider.notifier));
      if (restoreResult is! ResultSuccess) {
        return restoreResult.to<Backup>((value) => backup);
      }
      return ResultSuccess(value: backup);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    } finally {
      keepAliveLink.close();
    }
  }

  /// Do a backup with the given password.
  Future<Result<Backup>> doBackup(String password) async {
    KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
      if (currentCryptoStore == null) {
        throw _CryptoError();
      }
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      List<Totp> totps = await ref.read(totpRepositoryProvider.future);
      Backup backup = await Backup._create(password, currentCryptoStore, totps);
      await backup.save();
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(
        [
          ...(await future),
          backup.backupPath,
        ]..sort(),
      );
      return ResultSuccess(value: backup);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    } finally {
      keepAliveLink.close();
    }
  }

  /// Imports the [backupFile].
  Future<Result<BackupPath>> import(File backupFile) async {
    KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      if (!Backup._isBackupFileContentValid(backupFile)) {
        throw _InvalidBackupContentException();
      }
      DateTime? dateTime = BackupPath._extractFromBackupPath(backupFile);
      BackupPath backupPath = await BackupPath.create(dateTime: dateTime ?? DateTime.now());
      backupFile.copySync(backupPath.path);
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(
        [
          ...(await future),
          backupPath,
        ]..sort(),
      );
      return ResultSuccess(value: backupPath);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    } finally {
      keepAliveLink.close();
    }
  }

  /// Deletes the backup at [backupPath].
  Future<Result> deleteBackup(BackupPath backupPath) async {
    KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      await backupPath.delete();
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(
        (await future)..remove(backupPath),
      );
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    } finally {
      keepAliveLink.close();
    }
  }
}

/// Thrown when there is an encryption error.
class _CryptoError extends LocalizableException {
  /// Creates a new crypto error instance.
  _CryptoError()
    : super(
        localizedErrorMessage: translations.error.backup.crypto,
      );
}
