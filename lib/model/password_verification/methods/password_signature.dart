import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/crypto.dart';
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
  );

  /// Enables the password signature verification method.
  Future<bool> enable(String? password) async {
    Salt? salt = await Salt.readFromLocalStorage();
    if (password == null || salt == null) {
      return false;
    }
    String passwordSignature = await _generatePasswordSignature(password, salt);
    await SimpleSecureStorage.write(_kPasswordSignatureKey, passwordSignature);
    if (ref.mounted) {
      state = AsyncData(PasswordSignatureVerificationMethod(passwordSignature: passwordSignature));
    }
    return true;
  }

  /// Disables the password signature verification method.
  Future<void> disable() async {
    await SimpleSecureStorage.delete(_kPasswordSignatureKey);
    if (ref.mounted) {
      state = const AsyncData(PasswordSignatureVerificationMethod(passwordSignature: null));
    }
  }

  /// Generates the [password] signature with the given [salt].
  Future<String> _generatePasswordSignature(String password, Salt salt) async {
    CryptoStore cryptoStore = CryptoStore.fromPassword(password, salt);
    String passwordSignature = cryptoStore.hmacSecretKey.string(password, utf8).base64();
    return passwordSignature;
  }
}

/// Allows to verify the master password using the saved password signature.
class PasswordSignatureVerificationMethod with PasswordVerificationMethod {
  /// The password signature.
  final String? passwordSignature;

  /// Creates a new password signature verification method instance.
  const PasswordSignatureVerificationMethod({
    this.passwordSignature,
  });

  @override
  bool get enabled => passwordSignature != null;

  @override
  Future<bool> verify(String password) async {
    if (!(await super.verify(password))) {
      return false;
    }
    Salt? salt = await Salt.readFromLocalStorage();
    if (salt == null) {
      return false;
    }
    CryptoStore cryptoStore = CryptoStore.fromPassword(password, salt);
    return cryptoStore.hmacSecretKey.verify(base64.decode(passwordSignature!), utf8.encode(password));
  }
}
