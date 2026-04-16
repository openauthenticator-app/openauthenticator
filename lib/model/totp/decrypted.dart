import 'package:hashlib/hashlib.dart' as hashlib;
import 'package:hashlib_codecs/hashlib_codecs.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/totp/algorithm.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:uuid/uuid.dart';

/// Represents a TOTP, in its decrypted state.
class DecryptedTotp extends Totp {
  /// Creates a new decrypted TOTP instance.
  const DecryptedTotp({
    required super.uuid,
    required DecryptedData decryptedData,
    super.algorithm,
    super.digits,
    super.validity,
    required super.updatedAt,
  }) : super(
         encryptedData: decryptedData,
       );

  /// Creates a new decrypted TOTP instance.
  DecryptedTotp.fromTotp({
    required Totp totp,
    required DecryptedData decryptedData,
  }) : this(
         uuid: totp.uuid,
         decryptedData: decryptedData,
         algorithm: totp.algorithm,
         digits: totp.digits,
         validity: totp.validity,
         updatedAt: totp.updatedAt,
       );

  /// Returns the decrypted data.
  DecryptedData get decryptedData => super.encryptedData as DecryptedData;

  /// Returns the decrypted secret.
  String get secret => decryptedData.decryptedSecret;

  /// Returns the decrypted label.
  String? get label => decryptedData.decryptedLabel;

  /// Returns the decrypted issuer.
  String? get issuer => decryptedData.decryptedIssuer;

  /// Returns the decrypted image URL.
  String? get imageUrl => decryptedData.decryptedImageUrl;

  /// Returns the [totp_lib.Totp] instance.
  hashlib.TOTP get generator => hashlib.TOTP(
    fromBase32(secret),
    algo: (algorithm ?? Totp.kDefaultAlgorithm).mapsTo,
    digits: digits ?? Totp.kDefaultDigits,
    period: validity ?? Totp.kDefaultValidity,
  );

  /// Generates a code using the [generator].
  String generateCode() => generator.valueString();

  @override
  List<Object?> get props => [...super.props, secret, label, issuer];

  @override
  int compareTo(Totp other) {
    if (other.isDecrypted) {
      return (issuer ?? label ?? uuid).compareTo((other as DecryptedTotp).issuer ?? other.label ?? other.uuid);
    }
    return -1;
  }

  @override
  Future<Totp> decrypt(CryptoStore? cryptoStore) => Future.value(this);

  @override
  Totp copyWith({
    EncryptedData? encryptedData,
    Algorithm? algorithm,
    int? digits,
    Duration? validity,
    DateTime? updatedAt,
  }) => encryptedData is DecryptedData
      ? DecryptedTotp(
          uuid: uuid,
          decryptedData: encryptedData,
          algorithm: algorithm ?? this.algorithm,
          digits: digits ?? this.digits,
          validity: validity ?? this.validity,
          updatedAt: updatedAt ?? this.updatedAt,
        )
      : super.copyWith(
          encryptedData: encryptedData,
          algorithm: algorithm,
          digits: digits,
          validity: validity,
          updatedAt: updatedAt,
        );

  /// Manually creates a [DecryptedTotp].
  static Future<DecryptedTotp?> create({
    required CryptoStore? cryptoStore,
    String? uuid,
    required String secret,
    required String label,
    String? issuer,
    Algorithm? algorithm,
    int? digits,
    Duration? validity,
    String? imageUrl,
    DateTime? updatedAt,
  }) async {
    EncryptedData? encryptedData = await EncryptedData.encrypt(
      cryptoStore: cryptoStore,
      secret: secret,
      label: label,
      issuer: issuer,
      imageUrl: imageUrl,
    );
    if (encryptedData == null) {
      return null;
    }
    return DecryptedTotp(
      uuid: uuid ?? const Uuid().v4(),
      decryptedData: DecryptedData.fromEncryptedData(
        encryptedData: encryptedData,
        decryptedSecret: secret,
        decryptedLabel: label,
        decryptedIssuer: issuer,
        decryptedImageUrl: imageUrl,
      ),
      algorithm: algorithm,
      digits: digits,
      validity: validity,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Creates a new TOTP instance from the scanned QR code properties.
  static Future<DecryptedTotp?> fromUri(Uri uri, CryptoStore? cryptoStore) async {
    if (!uri.isScheme('otpauth') || uri.host != 'totp' || !uri.queryParameters.containsKey('secret')) {
      return null;
    }
    String label = Uri.decodeFull(uri.path);
    if (label.startsWith('/')) {
      label = label.substring(1);
    }
    int? validity = uri.queryParameters.containsKey(Totp.kValidityKey) ? int.tryParse(uri.queryParameters[Totp.kValidityKey]!) : null;
    return create(
      cryptoStore: cryptoStore,
      secret: uri.queryParameters[Totp.kSecretKey]!,
      label: label,
      issuer: uri.queryParameters[Totp.kIssuerKey],
      algorithm: uri.queryParameters.containsKey(Totp.kAlgorithmKey) ? Algorithm.fromString(uri.queryParameters[Totp.kAlgorithmKey]!) : null,
      digits: uri.queryParameters.containsKey(Totp.kDigitsKey) ? int.tryParse(uri.queryParameters[Totp.kDigitsKey]!) : null,
      validity: validity == null ? null : Duration(seconds: validity),
    );
  }

  /// Returns the URI associated to this TOTP instance.
  Uri get uri => toUri(
    secret: secret,
    label: label ?? uuid,
    issuer: issuer,
    algorithm: algorithm,
    digits: digits,
    validity: validity,
  );

  /// Converts the given TOTP parameters to an URI.
  static Uri toUri({
    required String secret,
    required String label,
    String? issuer,
    Algorithm? algorithm,
    int? digits,
    Duration? validity,
  }) {
    Map<String, dynamic> queryParameters = {};
    queryParameters[Totp.kSecretKey] = secret;
    if (issuer != null) {
      queryParameters[Totp.kIssuerKey] = issuer;
    }
    if (algorithm != null) {
      queryParameters[Totp.kAlgorithmKey] = algorithm.name.toLowerCase();
    }
    if (digits != null) {
      queryParameters[Totp.kDigitsKey] = digits.toString();
    }
    if (validity != null) {
      queryParameters[Totp.kValidityKey] = validity.inSeconds.toString();
    }
    return Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: label,
      queryParameters: queryParameters,
    );
  }
}

/// Allows to check if the TOTP instance is decrypted.
extension IsDecrypted on Totp {
  /// Returns whether the current TOTP instance is a decrypted secret.
  bool get isDecrypted => this is DecryptedTotp;
}

/// Everything that should be encrypted goes here.
class DecryptedData extends EncryptedData {
  /// The decrypted secret.
  final String decryptedSecret;

  /// The decrypted label.
  final String? decryptedLabel;

  /// The decrypted issuer.
  final String? decryptedIssuer;

  /// The decrypted image URL.
  final String? decryptedImageUrl;

  /// Creates a new decrypted data instance.
  const DecryptedData({
    required super.encryptedSecret,
    required super.encryptedLabel,
    super.encryptedIssuer,
    super.encryptedImageUrl,
    required super.encryptionSalt,
    required this.decryptedSecret,
    this.decryptedLabel,
    this.decryptedIssuer,
    this.decryptedImageUrl,
  });

  /// Creates a new decrypted data instance from the specified [encryptedData].
  DecryptedData.fromEncryptedData({
    required EncryptedData encryptedData,
    required String decryptedSecret,
    String? decryptedLabel,
    String? decryptedIssuer,
    String? decryptedImageUrl,
  }) : this(
         encryptedSecret: encryptedData.encryptedSecret,
         encryptedLabel: encryptedData.encryptedLabel,
         encryptedIssuer: encryptedData.encryptedIssuer,
         encryptedImageUrl: encryptedData.encryptedImageUrl,
         encryptionSalt: encryptedData.encryptionSalt,
         decryptedSecret: decryptedSecret,
         decryptedLabel: decryptedLabel,
         decryptedIssuer: decryptedIssuer,
         decryptedImageUrl: decryptedImageUrl,
       );

  /// Decrypts the passed [encryptedData].
  static Future<DecryptedData?> decrypt({
    CryptoStore? cryptoStore,
    required EncryptedData encryptedData,
  }) async {
    if (encryptedData is DecryptedData) {
      return encryptedData;
    }
    String? decryptedSecret = await cryptoStore?.decrypt(encryptedData.encryptedSecret);
    if (decryptedSecret == null) {
      return null;
    }
    String? decryptedLabel;
    if (encryptedData.encryptedLabel != null) {
      decryptedLabel = await cryptoStore?.decrypt(encryptedData.encryptedLabel!);
      if (decryptedLabel == null) {
        return null;
      }
    }
    String? decryptedIssuer;
    if (encryptedData.encryptedIssuer != null) {
      decryptedIssuer = await cryptoStore?.decrypt(encryptedData.encryptedIssuer!);
      if (decryptedIssuer == null) {
        return null;
      }
    }
    String? decryptedImageUrl;
    if (encryptedData.encryptedImageUrl != null) {
      decryptedImageUrl = await cryptoStore?.decrypt(encryptedData.encryptedImageUrl!);
      if (decryptedImageUrl == null) {
        return null;
      }
    }
    return DecryptedData.fromEncryptedData(
      encryptedData: encryptedData,
      decryptedSecret: decryptedSecret,
      decryptedIssuer: decryptedIssuer,
      decryptedLabel: decryptedLabel,
      decryptedImageUrl: decryptedImageUrl,
    );
  }

  /// Changes the encryption key of the current TOTP.
  Future<DecryptedData?> changeEncryptionKey(CryptoStore newCryptoStore) async {
    if (await canDecryptData(newCryptoStore)) {
      return this;
    }
    EncryptedData? encryptedData = await EncryptedData.encrypt(
      cryptoStore: newCryptoStore,
      secret: decryptedSecret,
      issuer: decryptedIssuer,
      label: decryptedLabel,
      imageUrl: decryptedImageUrl,
    );
    if (encryptedData == null) {
      return null;
    }
    return DecryptedData.fromEncryptedData(
      encryptedData: encryptedData,
      decryptedSecret: decryptedSecret,
      decryptedIssuer: decryptedIssuer,
      decryptedLabel: decryptedLabel,
      decryptedImageUrl: decryptedImageUrl,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    decryptedSecret,
    decryptedLabel,
    decryptedIssuer,
    decryptedImageUrl,
  ];
}
