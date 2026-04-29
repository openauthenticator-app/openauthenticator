import 'dart:async';
import 'dart:convert';

import 'package:cipherlib/cipherlib.dart';
import 'package:cipherlib/random.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hashlib/hashlib.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/password_verification/methods/password_signature.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The crypto store provider.
final cryptoStoreProvider = AsyncNotifierProvider<StoredCryptoStore, CryptoStore?>(StoredCryptoStore.new);

/// Allows to get and set the crypto store.
class StoredCryptoStore extends AsyncNotifier<CryptoStore?> {
  /// The password derived key storage key.
  static const String _kPasswordDerivedKeyKey = 'passwordDerivedKey';

  @override
  FutureOr<CryptoStore?> build() async {
    Salt? salt = await ref.watch(saltProvider.future);
    if (salt == null) {
      return null;
    }

    String? derivedKey = await SimpleSecureStorage.read(_kPasswordDerivedKeyKey);
    if (derivedKey == null) {
      return null;
    }

    return CryptoStore._(
      key: base64.decode(derivedKey),
      salt: salt,
    );
  }

  /// Deletes the current crypto store from the local storage.
  Future<void> deleteFromLocalStorage({bool deleteSalt = false}) async {
    await SimpleSecureStorage.delete(_kPasswordDerivedKeyKey);
    if (deleteSalt) {
      await ref.read(saltProvider.notifier).deleteFromLocalStorage();
    }
  }

  /// Uses the [cryptoStore] as [state].
  void use(CryptoStore cryptoStore) {
    if (ref.mounted) {
      state = AsyncData(cryptoStore);
    }
  }

  /// Changes the current crypto store password, preserving the current salt if possible.
  Future<CryptoStore> changeCryptoStore(
    String newPassword, {
    CryptoStore? newCryptoStore,
    bool checkSettings = true,
  }) async {
    Salt? salt = newCryptoStore?.salt;
    if (salt == null) {
      CryptoStore? currentCryptoStore = await future;
      salt = currentCryptoStore?.salt ?? Salt.generate();
    }
    if (newCryptoStore == null) {
      newCryptoStore = CryptoStore.fromPassword(newPassword, salt);
    } else {
      if (!(newCryptoStore.checkPasswordValidity(newPassword))) {
        throw _PasswordMismatchException();
      }
    }
    Future<void> saveCryptoStoreOnLocalStorage() async => await SimpleSecureStorage.write(_kPasswordDerivedKeyKey, base64.encode(newCryptoStore!.key));
    await ref.read(saltProvider.notifier).changeSalt(salt);
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
  /// The initialization vector length.
  static const int _initializationVectorLength = 96 ~/ 8;

  /// The key instance.
  @visibleForTesting
  final Uint8List key;

  /// The salt.
  final Salt salt;

  /// Creates a new crypto store instance.
  const CryptoStore._({
    required this.key,
    required this.salt,
  });

  /// Creates a [CryptoStoreWithPasswordSignature] from the given [password].
  CryptoStore.fromPassword(String password, Salt salt)
    : this._(
        key: _deriveKey(password, salt).bytes,
        salt: salt,
      );

  /// Generates a derived key from the given [password] and save it to the device secure storage.
  /// Also returns the salt that has been used.
  static Argon2HashDigest _deriveKey(String password, Salt salt) {
    Argon2 argon2 = Argon2(
      iterations: Argon2Parameters.iterations,
      memorySizeKB: Argon2Parameters.memorySize,
      parallelism: Argon2Parameters.parallelism,
      salt: salt.value,
    );
    return argon2.convert(utf8.encode(password));
  }

  /// Encrypts the given text.
  Uint8List? encrypt(String text) {
    Uint8List initializationVector = randomBytes(_initializationVectorLength);
    return Uint8List.fromList([
      ...initializationVector,
      ...AES(key).gcm(initializationVector).encryptString(text, utf8),
    ]);
  }

  /// Decrypts the given bytes.
  /// Returns `null` if not possible.
  String? decrypt(Uint8List encryptedData) {
    try {
      Uint8List initializationVector = encryptedData.sublist(0, _initializationVectorLength);
      Uint8List encryptedBytes = encryptedData.sublist(_initializationVectorLength);
      return utf8.decode(AES(key).gcm(initializationVector).decrypt(encryptedBytes));
    } catch (ex, stackTrace) {
      if (ex is! StateError) {
        handleException(ex, stackTrace);
      }
    }
    return null;
  }

  /// Checks if the given password is valid.
  bool checkPasswordValidity(String password) => _deriveKey(password, salt).isEqual(key);

  /// Checks if the given [encryptedData] could be decrypted using [decrypt].
  /// There seems to be no better way of doing this.
  /// The authentication tag doesn't seems to be accessible, BUT it should be checked
  /// before any decryption. So, if the validation fails, then the decryption exits immediately.
  /// The caveat is, if it works, then the whole data has to be proceeded.
  bool canDecrypt(Uint8List encryptedData) => decrypt(encryptedData) != null;

  /// Returns the HMAC secret key corresponding to the [key].
  MACHashBase get hmacSecretKey => sha256.hmac.by(key);
}

/// Thrown when the password entered for a new crypto store is incorrect.
class _PasswordMismatchException extends LocalizableException {
  /// Creates a new password mismatch exception instance.
  _PasswordMismatchException()
    : super(
        localizedErrorMessage: translations.error.passwordMismatch,
      );
}
