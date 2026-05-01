import 'dart:async';
import 'dart:convert';

import 'package:cipherlib/random.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hashlib/hashlib.dart';
import 'package:open_authenticator/model/crypto/derived_key.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/utils/result/handler.dart';

/// The crypto store provider.
final cryptoStoreProvider = AsyncNotifierProvider<CryptoStoreNotifier, CryptoStore?>(CryptoStoreNotifier.new);

/// Allows to get and set the crypto store.
class CryptoStoreNotifier extends AsyncNotifier<CryptoStore?> {
  @override
  FutureOr<CryptoStore?> build() async {
    DerivedKey? derivedKey = await ref.watch(derivedKeyProvider.future);
    if (derivedKey == null) {
      return null;
    }

    Salt? salt = await ref.watch(saltProvider.future);
    if (salt == null) {
      return null;
    }

    return CryptoStore._(
      key: derivedKey,
      salt: salt,
    );
  }
}

/// Allows to encrypt some data according to a key.
class CryptoStore with EquatableMixin {
  /// The initialization vector length.
  static const int _initializationVectorLength = 96 ~/ 8;

  /// The key instance.
  final DerivedKey key;

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
        key: DerivedKey.fromPassword(password, salt),
        salt: salt,
      );

  /// Encrypts the given text.
  Uint8List? encrypt(String text) {
    Uint8List initializationVector = randomBytes(_initializationVectorLength);
    return Uint8List.fromList([
      ...initializationVector,
      ...key.aes.gcm(initializationVector).encryptString(text, utf8),
    ]);
  }

  /// Decrypts the given bytes.
  /// Returns `null` if not possible.
  String? decrypt(Uint8List encryptedData) {
    try {
      Uint8List initializationVector = encryptedData.sublist(0, _initializationVectorLength);
      Uint8List encryptedBytes = encryptedData.sublist(_initializationVectorLength);
      return utf8.decode(key.aes.gcm(initializationVector).decrypt(encryptedBytes));
    } catch (ex, stackTrace) {
      if (ex is! StateError) {
        printException(ex, stackTrace);
      }
    }
    return null;
  }

  /// Checks if the given password is valid.
  bool checkPasswordValidity(String password) => DerivedKey.fromPassword(password, salt) == key;

  /// Checks if the given [encryptedData] could be decrypted using [decrypt].
  /// There seems to be no better way of doing this.
  /// The authentication tag doesn't seems to be accessible, BUT it should be checked
  /// before any decryption. So, if the validation fails, then the decryption exits immediately.
  /// The caveat is, if it works, then the whole data has to be proceeded.
  bool canDecrypt(Uint8List encryptedData) => decrypt(encryptedData) != null;

  /// Returns the HMAC secret key corresponding to the [key].
  MACHashBase get hmacSecretKey => key.hmacSecretKey;

  @override
  List<Object?> get props => [key, salt];
}
