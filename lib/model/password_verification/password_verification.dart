import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/password_verification/methods/crypto_store.dart';
import 'package:open_authenticator/model/password_verification/methods/method.dart';
import 'package:open_authenticator/model/password_verification/methods/password_signature.dart';
import 'package:open_authenticator/utils/result.dart';

/// The provider instance.
final passwordVerificationProvider = AsyncNotifierProvider.autoDispose<PasswordVerification, List<PasswordVerificationMethod>>(PasswordVerification.new);

/// Allows to check whether a given password is the user's master password.
class PasswordVerification extends AsyncNotifier<List<PasswordVerificationMethod>> {
  @override
  FutureOr<List<PasswordVerificationMethod>> build() async {
    CryptoStoreVerificationMethod cryptoStoreVerificationMethod = await ref.watch(cryptoStoreVerificationMethodProvider.future);
    PasswordSignatureVerificationMethod passwordSignatureVerificationMethod = await ref.watch(passwordSignatureVerificationMethodProvider.future);
    return List.unmodifiable([
      if (cryptoStoreVerificationMethod.enabled) cryptoStoreVerificationMethod,
      if (passwordSignatureVerificationMethod.enabled) passwordSignatureVerificationMethod,
    ]);
  }
}

/// Allows to check whether a password is valid thanks to the verification methods.
extension PasswordValidity on List<PasswordVerificationMethod> {
  /// Returns whether the given password is the user's master password.
  Future<Result<bool>> isPasswordValid(String password) async {
    try {
      int verificationCount = 0;
      for (PasswordVerificationMethod verificationMethod in this) {
        if (await verificationMethod.verify(password)) {
          verificationCount++;
          if (verificationMethod.isSure) {
            return const ResultSuccess(value: true);
          }
        } else {
          return const ResultSuccess(value: false);
        }
      }
      return ResultSuccess(value: verificationCount == length);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }
}
