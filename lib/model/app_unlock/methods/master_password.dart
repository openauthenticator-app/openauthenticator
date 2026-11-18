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
  Future<Result<String>> _tryUnlock(AppUnlockInteraction interaction, UnlockReason reason) async {
    if (reason != .openApp && reason != .sensibleAction) {
      final List<Totp> totps = await _ref.read(totpRepositoryProvider.future);
      if (totps.isEmpty) {
        return const ResultSuccess();
      }
    }
    if (!interaction.canInteract) {
      return const ResultCancelled();
    }

    final Result<String> result = await _promptMasterPasswordForUnlock(interaction, reason == .openApp ? translations.appUnlock.masterPasswordDialogMessage : null);
    if (result is! ResultSuccess<String>) {
      return result;
    }

    if (reason == .openApp) {
      await _ref.read(derivedKeyProvider.notifier).updateFromPassword(result.value, andWrite: false);
    }

    return ResultSuccess(value: result.value);
  }

  @override
  Future<void> onMethodChosen({ResultSuccess<String>? enableResult}) async {
    final String? password = enableResult?.valueOrNull;
    if (await _ref.read(passwordSignatureVerificationMethodProvider.notifier).enable(password)) {
      await _ref.read(derivedKeyProvider.notifier).deleteFromLocalStorage();
    }
  }

  @override
  Future<void> onMethodChanged({ResultSuccess<String>? disableResult}) async {
    await _ref.read(passwordSignatureVerificationMethodProvider.notifier).disable();
    final String? password = disableResult?.valueOrNull;
    if (password != null) {
      await _ref.read(derivedKeyProvider.notifier).updateFromPassword(password, andWrite: true);
    }
  }

  @override
  Future<CannotUnlockException?> canUnlock(UnlockReason reason) async {
    if (reason != .openApp && reason != .sensibleAction) {
      final List<Totp> totps = await _ref.read(totpRepositoryProvider.future);
      if (totps.isEmpty) {
        return null;
      }
    }
    final Salt? salt = await _ref.read(saltProvider.future);
    if (salt == null) {
      return MasterPasswordNoSalt();
    }
    final List<PasswordVerificationMethod> passwordVerificationMethods = await _ref.read(passwordVerificationProvider.future);
    if (passwordVerificationMethods.isEmpty) {
      return MasterPasswordNoPasswordVerificationMethodAvailable();
    }
    return null;
  }

  /// Prompts master password for unlock.
  Future<Result<String>> _promptMasterPasswordForUnlock(AppUnlockInteraction interaction, String? message) async {
    final String? password = await interaction.promptMasterPassword(
      message: message,
    );
    if (password == null) {
      return const ResultCancelled();
    }

    final Result<bool> passwordCheckResult = await (await _ref.read(passwordVerificationProvider.future)).isPasswordValid(password);
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
class MasterPasswordCheckException extends CannotUnlockException;
