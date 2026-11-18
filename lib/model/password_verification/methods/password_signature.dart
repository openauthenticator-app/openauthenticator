import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/crypto/store.dart';
import 'package:open_authenticator/model/password_verification/methods/method.dart';
import 'package:open_authenticator/model/secure_storage.dart';
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
  FutureOr<PasswordSignatureVerificationMethod> build() async {
    final CachedSimpleSecureStorage simpleSecureStorage = await ref.watch(secureStorageProvider.future);
    return PasswordSignatureVerificationMethod(
      passwordSignature: simpleSecureStorage.read(_kPasswordSignatureKey),
      salt: await ref.watch(saltProvider.future),
    );
  }

  /// Enables the password signature verification method.
  Future<bool> enable(String? password, {CryptoStore? derivedStore}) async {
    if (password == null) {
      return false;
    }
    final Salt? salt = await ref.read(saltProvider.future);
    if (salt == null) {
      return false;
    }
    final CryptoStore cryptoStore = derivedStore != null && derivedStore.salt == salt ? derivedStore : await CryptoStore.fromPasswordInIsolate(password, salt);
    final String passwordSignature = cryptoStore.hmacSecretKey.string(password, utf8).base64();
    final CachedSimpleSecureStorage simpleSecureStorage = await ref.read(secureStorageProvider.future);
    await simpleSecureStorage.writeCredential(_kPasswordSignatureKey, passwordSignature);
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

  /// Disables the password signature verification method.
  Future<void> disable() async {
    final CachedSimpleSecureStorage simpleSecureStorage = await ref.read(secureStorageProvider.future);
    await simpleSecureStorage.delete(_kPasswordSignatureKey);
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
    final CryptoStore cryptoStore = await CryptoStore.fromPasswordInIsolate(password, salt!);
    return cryptoStore.hmacSecretKey.verify(base64.decode(passwordSignature!), utf8.encode(password));
  }
}
