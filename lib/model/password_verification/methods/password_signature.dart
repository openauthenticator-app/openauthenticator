import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/crypto/store.dart';
import 'package:open_authenticator/model/password_verification/methods/method.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The provider instance.
final passwordSignatureVerificationMethodProvider = AsyncNotifierProvider<PasswordSignatureVerificationMethodNotifier, PasswordSignatureVerificationMethod>(
  PasswordSignatureVerificationMethodNotifier.new,
);

/// Allows to verify the master password using the saved password signature.
class PasswordSignatureVerificationMethodNotifier extends AsyncNotifier<PasswordSignatureVerificationMethod> {
  /// The password signature.
  static const String _kPasswordSignatureKey = 'passwordSignature';

  @override
  FutureOr<PasswordSignatureVerificationMethod> build() async => PasswordSignatureVerificationMethod(
    passwordSignature: await SimpleSecureStorage.read(_kPasswordSignatureKey),
    salt: await ref.watch(saltProvider.future),
  );

  /// Enables the password signature verification method.
  Future<bool> enable(String? password) async {
    if (password == null) {
      return false;
    }
    Salt? salt = await ref.read(saltProvider.future);
    if (salt == null) {
      return false;
    }
    CryptoStore cryptoStore = CryptoStore.fromPassword(password, salt);
    String passwordSignature = cryptoStore.hmacSecretKey.string(password, utf8).base64();
    await SimpleSecureStorage.write(_kPasswordSignatureKey, passwordSignature);
    if (ref.mounted) {
      state = AsyncData(
        PasswordSignatureVerificationMethod(
          passwordSignature: passwordSignature,
          salt: salt,
        ),
      );
    }
    return true;
  }

  /// Updates the current password.
  Future<void> updatePasswordSignature(String password) async => await enable(password);

  /// Disables the password signature verification method.
  Future<void> disable() async {
    await SimpleSecureStorage.delete(_kPasswordSignatureKey);
    if (ref.mounted) {
      state = const AsyncData(PasswordSignatureVerificationMethod());
    }
  }
}

/// Allows to verify the master password using the saved password signature.
class PasswordSignatureVerificationMethod with PasswordVerificationMethod {
  /// The password signature.
  final String? passwordSignature;

  /// The salt instance.
  final Salt? salt;

  /// Creates a new password signature verification method instance.
  const PasswordSignatureVerificationMethod({
    this.passwordSignature,
    this.salt,
  });

  @override
  bool get enabled => passwordSignature != null && salt != null;

  @override
  Future<bool> verify(String password) async {
    if (!(await super.verify(password))) {
      return false;
    }
    CryptoStore cryptoStore = CryptoStore.fromPassword(password, salt!);
    return cryptoStore.hmacSecretKey.verify(base64.decode(passwordSignature!), utf8.encode(password));
  }
}
