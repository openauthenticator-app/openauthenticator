import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/password_verification/methods/method.dart';

/// The provider instance.
final cryptoStoreVerificationMethodProvider = FutureProvider.autoDispose<CryptoStoreVerificationMethod>((ref) async {
  CryptoStore? cryptoStore = await ref.watch(cryptoStoreProvider.future);
  return CryptoStoreVerificationMethod(
    cryptoStore: cryptoStore,
  );
});

/// Allows to verify the master password using the current [CryptoStore].
class CryptoStoreVerificationMethod with PasswordVerificationMethod {
  /// The crypto store instance.
  final CryptoStore? _cryptoStore;

  /// Creates a new crypto store verification method instance.
  const CryptoStoreVerificationMethod({
    required CryptoStore? cryptoStore,
  }) : _cryptoStore = cryptoStore;

  @override
  bool get enabled => _cryptoStore != null;

  @override
  Future<bool> verify(String password) async {
    if (!(await super.verify(password))) {
      return false;
    }
    return (await _cryptoStore?.checkPasswordValidity(password)) == true;
  }
}
