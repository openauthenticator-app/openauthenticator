part of 'method.dart';

/// Enter master password.
class MasterPasswordAppUnlockMethod extends AppUnlockMethod<String> {
  /// The master password app unlock method id.
  static const String kMethodId = 'masterPassword';

  /// Creates a new master password app unlock method instance.
  const MasterPasswordAppUnlockMethod._({
    required super.ref,
  }) : super(
         id: kMethodId,
       );

  @override
  Future<Result<String>> _tryUnlock(BuildContext context, UnlockReason reason) async {
    if (reason != .openApp && reason != .sensibleAction) {
      List<Totp> totps = await _ref.read(totpRepositoryProvider.future);
      if (totps.isEmpty) {
        return const ResultSuccess();
      }
    }
    if (!context.mounted) {
      return const ResultCancelled();
    }

    Result<String> result = await _promptMasterPasswordForUnlock(context, reason == .openApp ? translations.appUnlock.masterPasswordDialogMessage : null);
    if (result is! ResultSuccess<String>) {
      return result;
    }

    if (reason == .openApp) {
      Salt? salt = await Salt.readFromLocalStorage();
      _ref.read(cryptoStoreProvider.notifier).use(CryptoStore.fromPassword(result.value, salt!));
    }

    return ResultSuccess(value: result.value);
  }

  @override
  Future<void> onMethodChosen({ResultSuccess<String>? enableResult}) async {
    String? password = enableResult?.valueOrNull;
    if (await _ref.read(passwordSignatureVerificationMethodProvider.notifier).enable(password)) {
      await _ref.read(cryptoStoreProvider.notifier).deleteFromLocalStorage();
    }
  }

  @override
  Future<void> onMethodChanged({ResultSuccess<String>? disableResult}) async {
    await _ref.read(passwordSignatureVerificationMethodProvider.notifier).disable();
    String? password = disableResult?.valueOrNull;
    if (password != null) {
      await _ref.read(cryptoStoreProvider.notifier).changeCryptoStore(password, checkSettings: false);
    }
  }

  @override
  Future<CannotUnlockException?> canUnlock(UnlockReason reason) async {
    if (reason != .openApp && reason != .sensibleAction) {
      List<Totp> totps = await _ref.read(totpRepositoryProvider.future);
      if (totps.isEmpty) {
        return null;
      }
    }
    if (!(await _ensureSaltAvailable())) {
      return MasterPasswordNoSalt();
    }
    List<PasswordVerificationMethod> passwordVerificationMethods = await _ref.read(passwordVerificationProvider.future);
    if (passwordVerificationMethods.isEmpty) {
      return MasterPasswordNoPasswordVerificationMethodAvailable();
    }
    return null;
  }

  /// Ensures that the local salt exists, restoring it from the TOTP list when possible.
  Future<bool> _ensureSaltAvailable() async {
    if (await Salt.readFromLocalStorage() != null) {
      return true;
    }
    try {
      List<Totp> totps = await _ref.read(totpRepositoryProvider.future);
      Salt? salt = totps.firstOrNull?.encryptedData.encryptionSalt;
      if (salt == null) {
        return false;
      }
      await salt.saveToLocalStorage();
      _ref.invalidate(cryptoStoreProvider);
      _ref.invalidate(cryptoStoreVerificationMethodProvider);
      _ref.invalidate(passwordVerificationProvider);
      return true;
    } catch (ex, stackTrace) {
      handleException(ex, stackTrace);
      return false;
    }
  }

  /// Prompts master password for unlock.
  Future<Result<String>> _promptMasterPasswordForUnlock(BuildContext context, String? message) async {
    String? password = await MasterPasswordInputDialog.prompt(
      context,
      message: message,
    );
    if (password == null) {
      return const ResultCancelled();
    }

    Result<bool> passwordCheckResult = await (await _ref.read(passwordVerificationProvider.future)).isPasswordValid(password);
    if (passwordCheckResult is! ResultSuccess || !(passwordCheckResult as ResultSuccess<bool>).value) {
      return passwordCheckResult is ResultError
          ? passwordCheckResult.to<String>((_) => null)
          : ResultError(
              exception: MasterPasswordCheckException(),
            );
    }
    return ResultSuccess<String>(value: password);
  }
}

/// Indicates that the salt has not been saved on the device.
class MasterPasswordNoSalt extends CannotUnlockException {
  /// Creates a new master password no salt exception instance.
  MasterPasswordNoSalt()
    : super(
        localizedErrorMessage: translations.error.appUnlock.noPasswordVerificationMethodAvailable,
      );
}

/// Indicates that no password verification method is available.
class MasterPasswordNoPasswordVerificationMethodAvailable extends CannotUnlockException {
  /// Creates a new master password no password verification method available exception instance.
  MasterPasswordNoPasswordVerificationMethodAvailable()
    : super(
        localizedErrorMessage: translations.error.appUnlock.noPasswordVerificationMethodAvailable,
      );
}

/// Indicates that the master password is invalid.
class MasterPasswordCheckException extends CannotUnlockException {}
