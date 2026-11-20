part of 'backup.dart';

/// The backup store provider.
final AsyncNotifierProvider<BackupStore, List<BackupPath>> backupStoreProvider = AsyncNotifierProvider.autoDispose<BackupStore, List<BackupPath>>(BackupStore.new);

/// Contains all backups.
class BackupStore extends AsyncNotifier<List<BackupPath>> {
  @override
  FutureOr<List<BackupPath>> build() async => (await BackupPath.list().toList())..sort();

  /// Restores the [backupPath] with the given [password].
  Future<Result<Backup>> restoreBackup(BackupPath backupPath, String password) async {
    final KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      final CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
      if (currentCryptoStore == null) {
        throw _CryptoError();
      }
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      final Backup backup = await backupPath.read(currentCryptoStore, password);
      final Result restoreResult = await backup.restore(ref.read(totpRepositoryProvider.notifier));
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
    final KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      final CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      final List<Totp> totps = await ref.read(totpRepositoryProvider.future);
      final Backup backup = await Backup._create(password, currentCryptoStore, totps);
      await backup.save();
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(
        [
          ...(await future).where((existing) => existing.path != backup.backupPath.path),
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
    final KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      await Backup._readContent(backupFile);
      final DateTime? dateTime = BackupPath._extractFromBackupPath(backupFile);
      final BackupPath backupPath = await BackupPath.create(dateTime: dateTime ?? DateTime.now());
      try {
        await backupFile.copy(backupPath.path);
      } catch (_) {
        await backupPath.delete();
        rethrow;
      }
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(
        [
          ...(await future).where((existing) => existing.path != backupPath.path),
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
    final KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      await backupPath.delete();
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = AsyncData(
        [
          for (final path in await future)
            if (path.path != backupPath.path) path,
        ],
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
