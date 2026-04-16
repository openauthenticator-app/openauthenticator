import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/totp/algorithm.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';

/// Represents a TOTP in its encrypted state.
class Totp extends Equatable implements Comparable<Totp> {
  /// The UUID key.
  static const String kUuidKey = 'uuid';

  /// The secret key.
  static const String kSecretKey = 'secret';

  /// The label key.
  static const String kLabelKey = 'label';

  /// The issuer key.
  static const String kIssuerKey = 'issuer';

  /// The algorithm key.
  static const String kAlgorithmKey = 'algorithm';

  /// The digits key.
  static const String kDigitsKey = 'digits';

  /// The validity key.
  static const String kValidityKey = 'period';

  /// The image URL key.
  static const String kImageUrlKey = 'imageUrl';

  /// The encryption salt key.
  static const String kEncryptionSaltKey = 'encryptionSalt';

  /// The updated timestamp key.
  static const String kUpdatedAtKey = 'updatedAt';

  /// The default algorithm to use.
  static const Algorithm kDefaultAlgorithm = Algorithm.sha1;

  /// The default digits to use.
  static const int kDefaultDigits = 6;

  /// The default validity to use.
  static const Duration kDefaultValidity = Duration(seconds: 30);

  /// The TOTP UUID.
  final String uuid;

  /// All encrypted data.
  final EncryptedData encryptedData;

  /// The algorithm.
  final Algorithm? algorithm;

  /// The digit count.
  final int? digits;

  /// The validity period.
  final Duration? validity;

  /// The last update date.
  final DateTime updatedAt;

  /// Creates a new TOTP instance.
  const Totp({
    required this.uuid,
    required this.encryptedData,
    this.algorithm,
    this.digits,
    this.validity,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    uuid,
    encryptedData,
    algorithm,
    digits,
    validity,
    updatedAt,
  ];

  /// Tries to decrypt the current TOTP [secret].
  /// Returns the current instance if failed.
  Future<Totp> decrypt(CryptoStore? cryptoStore) async {
    DecryptedData? decryptedData = await DecryptedData.decrypt(
      cryptoStore: cryptoStore,
      encryptedData: encryptedData,
    );
    if (decryptedData == null) {
      return this;
    }
    return DecryptedTotp.fromTotp(
      totp: this,
      decryptedData: decryptedData,
    );
  }

  @override
  int compareTo(Totp other) => uuid.compareTo(other.uuid);

  /// Changes the encryption key of the current TOTP.
  Future<DecryptedTotp?> changeEncryptionKey(CryptoStore previousCryptoStore, CryptoStore newCryptoStore) async {
    Totp result = await decrypt(previousCryptoStore);
    if (!result.isDecrypted) {
      result = await decrypt(newCryptoStore);
      if (!result.isDecrypted) {
        return null;
      }
    }
    DecryptedData? decryptedData = await (result as DecryptedTotp).decryptedData.changeEncryptionKey(newCryptoStore);
    if (decryptedData == null) {
      return null;
    }
    return result.isDecrypted
        ? DecryptedTotp(
            uuid: result.uuid,
            decryptedData: decryptedData,
            algorithm: result.algorithm,
            digits: result.digits,
            validity: result.validity,
            updatedAt: result.updatedAt,
          )
        : null;
  }

  /// Returns a copy of the current TOTP instance.
  Totp copyWith({
    EncryptedData? encryptedData,
    Algorithm? algorithm,
    int? digits,
    Duration? validity,
    DateTime? updatedAt,
  }) => Totp(
    uuid: uuid,
    encryptedData: encryptedData ?? this.encryptedData,
    algorithm: algorithm ?? this.algorithm,
    digits: digits ?? this.digits,
    validity: validity ?? this.validity,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Everything that should be encrypted goes here.
class EncryptedData extends Equatable {
  /// The encrypted data.
  final Uint8List encryptedSecret;

  /// The encrypted label.
  final Uint8List? encryptedLabel;

  /// The encrypted issuer.
  final Uint8List? encryptedIssuer;

  /// The image URL.
  final Uint8List? encryptedImageUrl;

  /// The salt that has encrypted the secret.
  /// Stored "just in case".
  final Salt encryptionSalt;

  /// Creates a new encrypted data instance.
  const EncryptedData({
    required this.encryptedSecret,
    required this.encryptedLabel,
    this.encryptedIssuer,
    this.encryptedImageUrl,
    required this.encryptionSalt,
  });

  /// Encrypts the passed data.
  static Future<EncryptedData?> encrypt({
    CryptoStore? cryptoStore,
    required String secret,
    String? label,
    String? issuer,
    String? imageUrl,
  }) async {
    Uint8List? encryptedSecret = await cryptoStore?.encrypt(secret);
    if (encryptedSecret == null) {
      return null;
    }
    Uint8List? encryptedLabel;
    if (label != null) {
      encryptedLabel = await cryptoStore?.encrypt(label);
      if (encryptedLabel == null) {
        return null;
      }
    }
    Uint8List? encryptedIssuer;
    if (issuer != null) {
      encryptedIssuer = await cryptoStore?.encrypt(issuer);
      if (encryptedIssuer == null) {
        return null;
      }
    }
    Uint8List? encryptedImageUrl;
    if (imageUrl != null) {
      encryptedImageUrl = await cryptoStore?.encrypt(imageUrl);
      if (encryptedImageUrl == null) {
        return null;
      }
    }
    return EncryptedData(
      encryptedSecret: encryptedSecret,
      encryptedLabel: encryptedLabel,
      encryptedIssuer: encryptedIssuer,
      encryptedImageUrl: encryptedImageUrl,
      encryptionSalt: cryptoStore!.salt,
    );
  }

  /// Returns whether the given [cryptoStore] can decrypt this instance.
  Future<bool> canDecryptData(CryptoStore cryptoStore) => cryptoStore.canDecrypt(encryptedSecret);

  @override
  List<Object?> get props => [
    encryptedSecret,
    encryptedLabel,
    encryptedIssuer,
    encryptedImageUrl,
    encryptionSalt,
  ];
}
