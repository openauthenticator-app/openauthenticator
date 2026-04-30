import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hashlib/hashlib.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/crypto/key.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/password_verification/methods/password_signature.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The derived key provider instance.
final derivedKeyProvider = AsyncNotifierProvider<DerivedKeyNotifier, DerivedKey?>(DerivedKeyNotifier.new);

/// Allows to get and set the derived key.
class DerivedKeyNotifier extends AsyncNotifier<DerivedKey?> {
  /// The password derived key storage key.
  static const String _kPasswordDerivedKeyKey = 'passwordDerivedKey';

  @override
  FutureOr<DerivedKey?> build() async {
    String? derivedKey = await SimpleSecureStorage.read(_kPasswordDerivedKeyKey);
    return derivedKey == null ? null : DerivedKey._base64Decode(string: derivedKey);
  }

  /// Creates a new derived key instance using the [password] and uses it as [state].
  Future<DerivedKey?> updateFromPassword(String password, {bool? andWrite}) async {
    Salt? salt = await ref.read(saltProvider.future);
    if (salt == null) {
      return null;
    }
    DerivedKey newKey = DerivedKey.fromPassword(password, salt);
    String unlockMethod = await ref.read(appUnlockMethodSettingsEntryProvider.future);
    if (unlockMethod == MasterPasswordAppUnlockMethod.kMethodId) {
      await ref.read(passwordSignatureVerificationMethodProvider.notifier).updatePasswordSignature(password);
    }
    if (ref.mounted) {
      state = AsyncData(newKey);
    }
    andWrite ??= unlockMethod != MasterPasswordAppUnlockMethod.kMethodId;
    if (andWrite) {
      await SimpleSecureStorage.write(_kPasswordDerivedKeyKey, base64.encode(newKey.value));
    }
    return newKey;
  }

  /// Deletes the current derived key from the local storage.
  Future<void> deleteFromLocalStorage() async => await SimpleSecureStorage.delete(_kPasswordDerivedKeyKey);
}

/// Represents a derived key.
class DerivedKey extends CryptoKey {
  /// Creates a new key instance using the [value].
  const DerivedKey._fromRawValue({
    required super.value,
  }) : super.fromRawValue();

  /// Creates a new derived key instance using the Base 64 encoded [string].
  DerivedKey._base64Decode({
    required super.string,
  }) : super.base64Decode();

  /// Creates a derived key from a given [password] and a [salt].
  DerivedKey.fromPassword(String password, Salt salt)
    : this._fromRawValue(
        value: Argon2(
          iterations: Argon2Parameters.iterations,
          memorySizeKB: Argon2Parameters.memorySize,
          parallelism: Argon2Parameters.parallelism,
          salt: salt.value,
        ).convert(utf8.encode(password)).bytes,
      );
}
