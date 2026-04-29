import 'dart:async';
import 'dart:convert';

import 'package:cipherlib/random.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The salt provider instance.
final saltProvider = AsyncNotifierProvider<StoredSalt, Salt?>(StoredSalt.new);

/// Allows to get and set the salt.
class StoredSalt extends AsyncNotifier<Salt?> {
  /// The password derived key storage key.
  static const String _kPasswordDerivedKeySaltKey = 'passwordDerivedKeySalt';

  @override
  Future<Salt?> build() async {
    String? value = await SimpleSecureStorage.read(_kPasswordDerivedKeySaltKey);
    if (value != null) {
      return Salt.fromRawValue(
        value: base64.decode(value),
      );
    }
    return await _tryRecoverSaltFromDatabase();
  }

  /// Tries to recover the salt from the database.
  Future<Salt?> _tryRecoverSaltFromDatabase() async {
    List<Totp> totps = await ref.read(appDatabaseProvider).listTotps();
    Salt? salt = totps.firstOrNull?.encryptedData.encryptionSalt;
    if (salt != null) {
      await _saveToLocalStorage(salt);
    }
    return salt;
  }

  /// Changes the current salt.
  Future<void> changeSalt(Salt salt) async {
    _saveToLocalStorage(salt);
    if (ref.mounted) {
      state = AsyncData(salt);
    }
  }

  /// Saves the given [salt] to the local storage.
  Future<void> _saveToLocalStorage(Salt salt) async => await SimpleSecureStorage.write(_kPasswordDerivedKeySaltKey, base64.encode(salt.value));

  /// Deletes the current salt from the local storage and resets the current state.
  Future<void> deleteFromLocalStorage() async {
    await SimpleSecureStorage.delete(_kPasswordDerivedKeySaltKey);
    if (ref.mounted) {
      state = const AsyncData(null);
    }
  }
}

/// Represents a decoded salt.
class Salt {
  /// The salt length.
  static const int _saltLength = 256 ~/ 8;

  /// The salt value.
  final Uint8List value;

  /// Creates a new salt instance.
  const Salt.fromRawValue({
    required this.value,
  });

  /// Generates a random salt.
  static Salt generate() => Salt.fromRawValue(
    value: randomBytes(_saltLength),
  );

  @override
  String toString() => base64.encode(value);
}
