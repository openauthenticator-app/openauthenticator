import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hashlib/hashlib.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/password_verification/methods/password_signature.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';
import 'package:webcrypto/webcrypto.dart';

/// The crypto store provider.
final cryptoStoreProvider = AsyncNotifierProvider<StoredCryptoStore, CryptoStore?>(StoredCryptoStore.new);

/// Allows to get and set the crypto store.
class StoredCryptoStore extends AsyncNotifier<CryptoStore?> {
  /// The password derived key storage key.
  static const String _kPasswordDerivedKeyKey = 'passwordDerivedKey';

  @override
  FutureOr<CryptoStore?> build() async {
    Salt? salt = await Salt.readFromLocalStorage();
    if (salt == null) {
      return null;
    }

    String? derivedKey = await SimpleSecureStorage.read(_kPasswordDerivedKeyKey);
    if (derivedKey == null) {
      return null;
    }

    return CryptoStore._(
      key: await AesGcmSecretKey.importRawKey(base64.decode(derivedKey)),
      salt: salt,
    );
  }

  /// Deletes the current crypto store from the local storage.
  Future<void> deleteFromLocalStorage({bool deleteSalt = false}) async {
    await SimpleSecureStorage.delete(_kPasswordDerivedKeyKey);
    if (deleteSalt) {
      await Salt.deleteFromLocalStorage();
    }
  }

  /// Uses the [cryptoStore] as [state].
  void use(CryptoStore cryptoStore) {
    if (ref.mounted) {
      state = AsyncData(cryptoStore);
    }
  }

  /// Changes the current crypto store password, preserving the current salt if possible.
  Future<CryptoStore> changeCryptoStore(String newPassword, {CryptoStore? newCryptoStore, bool checkSettings = true}) async {
    Salt? salt = newCryptoStore?.salt;
    if (salt == null) {
      CryptoStore? currentCryptoStore = await future;
      salt = currentCryptoStore?.salt ?? (await Salt.generate());
    }
    if (newCryptoStore == null) {
      newCryptoStore = await CryptoStore.fromPassword(newPassword, salt);
    } else {
      if (!(await newCryptoStore.checkPasswordValidity(newPassword))) {
        throw _PasswordMismatchException();
      }
    }
    Future<void> saveCryptoStoreOnLocalStorage() async => await SimpleSecureStorage.write(_kPasswordDerivedKeyKey, base64.encode(await newCryptoStore!.key.exportRawKey()));
    await salt.saveToLocalStorage();
    if (checkSettings) {
      String unlockMethod = await ref.read(appUnlockMethodSettingsEntryProvider.future);
      if (unlockMethod == MasterPasswordAppUnlockMethod.kMethodId) {
        await ref.read(passwordSignatureVerificationMethodProvider.notifier).enable(newPassword);
      } else {
        await saveCryptoStoreOnLocalStorage();
      }
    } else {
      await saveCryptoStoreOnLocalStorage();
    }
    use(newCryptoStore);
    return newCryptoStore;
  }
}

/// Allows to encrypt some data according to a key.
class CryptoStore {
  /// The key length.
  static const int _keyLength = 256 ~/ 8;

  /// The initialization vector length.
  static const int _initializationVectorLength = 96 ~/ 8;

  /// The key instance.
  final AesGcmSecretKey key;

  /// The salt.
  final Salt salt;

  /// Creates a new crypto store instance.
  const CryptoStore._({
    required this.key,
    required this.salt,
  });

  /// Creates a [CryptoStoreWithPasswordSignature] from the given [password].
  static Future<CryptoStore> fromPassword(String password, Salt salt) async {
    Uint8List derivedKey = await _deriveKey(password, salt);
    return CryptoStore._(
      key: await AesGcmSecretKey.importRawKey(derivedKey),
      salt: salt,
    );
  }

  /// Generates a derived key from the given [password] and save it to the device secure storage.
  /// Also returns the salt that has been used.
  static Future<Uint8List> _deriveKey(String password, Salt salt) async {
    Argon2 argon2 = Argon2(
      iterations: Argon2Parameters.iterations,
      memorySizeKB: Argon2Parameters.memorySize,
      parallelism: Argon2Parameters.parallelism,
      salt: salt.value,
    );
    return argon2.convert(utf8.encode(password)).bytes;
  }

  /// Encrypts the given text.
  Future<Uint8List?> encrypt(String text) async {
    Uint8List initializationVector = Uint8List(_initializationVectorLength);
    fillRandomBytes(initializationVector);
    Uint8List data = utf8.encode(text);
    return Uint8List.fromList([
      ...initializationVector,
      ...await key.encryptBytes(data, initializationVector),
    ]);
  }

  /// Decrypts the given bytes.
  /// Returns `null` if not possible.
  Future<String?> decrypt(Uint8List encryptedData) async {
    try {
      Uint8List initializationVector = encryptedData.sublist(0, _initializationVectorLength);
      Uint8List encryptedBytes = encryptedData.sublist(_initializationVectorLength);
      return utf8.decode(await key.decryptBytes(encryptedBytes, initializationVector));
    } catch (ex, stackTrace) {
      if (ex.toString() != 'error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT') {
        handleException(ex, stackTrace);
      }
    }
    return null;
  }

  /// Checks if the given password is valid.
  Future<bool> checkPasswordValidity(String password) async {
    Uint8List derivedKey = await _deriveKey(password, salt);
    return memEquals(derivedKey, await key.exportRawKey());
  }

  /// Checks if the given [encryptedData] could be decrypted using [decrypt].
  /// There seems to be no better way of doing this.
  /// The authentication tag doesn't seems to be accessible, BUT it should be checked
  /// before any decryption. So, if the validation fails, then the decryption exits immediately.
  /// The caveat is, if it works, then the whole data has to be proceeded.
  Future<bool> canDecrypt(Uint8List encryptedData) async => await decrypt(encryptedData) != null;
}

/// Represents a decoded salt.
class Salt {
  /// The salt length.
  static const int _saltLength = CryptoStore._keyLength;

  /// The password derived key storage key.
  static const String _kPasswordDerivedKeySaltKey = 'passwordDerivedKeySalt';

  /// The salt value.
  final Uint8List value;

  /// Creates a new salt instance.
  const Salt.fromRawValue({
    required this.value,
  });

  /// Reads the salt from local storage.
  static Future<Salt?> readFromLocalStorage() async {
    String? value = await SimpleSecureStorage.read(_kPasswordDerivedKeySaltKey);
    if (value == null) {
      return null;
    }
    return Salt.fromRawValue(
      value: base64.decode(value),
    );
  }

  /// Generates a random salt.
  static Future<Salt> generate() async {
    Uint8List salt = Uint8List(_saltLength);
    fillRandomBytes(salt);
    return Salt.fromRawValue(
      value: salt,
    );
  }

  /// Deletes the salt from local storage.
  static Future<void> deleteFromLocalStorage() async => await SimpleSecureStorage.delete(_kPasswordDerivedKeySaltKey);

  /// Writes the salt to the secure storage.
  Future<void> saveToLocalStorage() async => await SimpleSecureStorage.write(_kPasswordDerivedKeySaltKey, base64.encode(value));

  @override
  String toString() => base64.encode(value);
}

/// Thrown when the password entered for a new crypto store is incorrect.
class _PasswordMismatchException extends LocalizableException {
  /// Creates a new password mismatch exception instance.
  _PasswordMismatchException()
    : super(
        localizedErrorMessage: translations.error.passwordMismatch,
      );
}
