import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/crypto/key.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/secure_storage.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The salt provider instance.
final saltProvider = AsyncNotifierProvider<SaltNotifier, Salt?>(SaltNotifier.new);

/// Allows to get and set the salt.
class SaltNotifier extends AsyncNotifier<Salt?> {
  /// The password derived key storage key.
  static const String _kPasswordDerivedKeySaltKey = 'passwordDerivedKeySalt';

  @override
  Future<Salt?> build() async {
    final CachedSimpleSecureStorage simpleSecureStorage = await ref.watch(secureStorageProvider.future);
    final String? value = simpleSecureStorage.read(_kPasswordDerivedKeySaltKey);
    if (value != null) {
      return Salt.base64Decode(
        string: value,
      );
    }
    return await _tryRecoverSaltFromDatabase();
  }

  /// Tries to recover the salt from the database.
  Future<Salt?> _tryRecoverSaltFromDatabase() async {
    final List<Totp> totps = await ref.read(appDatabaseProvider).listTotps();
    final Map<Salt, int> salts = {};
    (Salt, int)? best;
    for (final Totp totp in totps) {
      final int? count = salts[totp.encryptedData.encryptionSalt];
      final int newCount = count == null ? 1 : (count + 1);
      salts[totp.encryptedData.encryptionSalt] = newCount;
      if (best == null || newCount > best.$2) {
        best = (totp.encryptedData.encryptionSalt, newCount);
      }
    }
    final Salt? salt = best?.$1;
    if (salt != null) {
      await _saveToLocalStorage(salt);
    }
    return salt;
  }

  /// Generates a new salt if needed and updates the state.
  Future<void> generateIfNeeded() async {
    Salt? salt = await future;
    if (salt != null) {
      return;
    }
    salt = Salt.generate();
    await changeSalt(salt);
  }

  /// Changes the current salt.
  Future<void> changeSalt(Salt? salt) async {
    await _saveToLocalStorage(salt);
    if (ref.mounted) {
      state = AsyncData(salt);
    }
  }

  /// Saves the given [salt] to the local storage.
  Future<void> _saveToLocalStorage(Salt? salt) async {
    final CachedSimpleSecureStorage simpleSecureStorage = await ref.read(secureStorageProvider.future);
    if (salt == null) {
      await simpleSecureStorage.delete(_kPasswordDerivedKeySaltKey);
    } else {
      await simpleSecureStorage.write(_kPasswordDerivedKeySaltKey, base64.encode(salt.value));
    }
  }
}

/// Represents a decoded salt.
class Salt extends CryptoKey {
  /// The salt length.
  static const int _saltLength = 256 ~/ 8;

  /// Creates a new salt instance.
  const Salt.fromRawValue({
    required super.value,
  }) : super.fromRawValue();

  /// Creates a new salt instance using the Base 64 encoded [string].
  Salt.base64Decode({
    required String string,
  }) : this.fromRawValue(
         value: base64.decode(string),
       );

  /// Generates a random salt.
  Salt.generate() : super.generate(_saltLength);

  @override
  String toString() => base64.encode(value);
}
