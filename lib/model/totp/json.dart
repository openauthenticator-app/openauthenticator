import 'dart:typed_data';

import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/totp/algorithm.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/json.dart';

/// Gives some useful properties for serializing TOTPs.
extension JsonTotp on Totp {
  /// Force creating a new TOTP from the specified JSON data.
  static Totp fromJson(JsonMap data, {String? uuid}) => tryFromJson(withSupportedParameters(data), uuid: uuid)!;

  /// Older clients accepted unusable periods and digit counts. Keep their encrypted data and use TOTP defaults.
  static JsonMap withSupportedParameters(JsonMap data) {
    if (Totp.validDigits(data[Totp.kDigitsKey]) && Totp.validPeriod(data[Totp.kValidityKey])) {
      return data;
    }
    return {
      for (final MapEntry<String, dynamic> field in data.entries)
        if ((field.key != Totp.kDigitsKey || Totp.validDigits(field.value)) && (field.key != Totp.kValidityKey || Totp.validPeriod(field.value))) field.key: field.value,
    };
  }

  /// Creates a new TOTP from the specified JSON data.
  static Totp? tryFromJson(JsonMap data, {String? uuid}) {
    final EncryptedData? encryptedData = JsonEncryptedData.fromJson(data);
    final Object? id = uuid ?? data[Totp.kUuidKey];
    final Object? timestamp = data[Totp.kUpdatedAtKey];
    final Object? algorithm = data[Totp.kAlgorithmKey];
    if (encryptedData == null ||
        id is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        timestamp is! int ||
        timestamp.abs() > 8640000000000000 ||
        !Totp.validPeriod(data[Totp.kValidityKey]) ||
        !Totp.validDigits(data[Totp.kDigitsKey]) ||
        (algorithm != null && (algorithm is! String || Algorithm.fromString(algorithm) == null))) {
      return null;
    }
    return Totp(
      uuid: id,
      encryptedData: encryptedData,
      algorithm: data[Totp.kAlgorithmKey] is! String ? null : Algorithm.fromString(data[Totp.kAlgorithmKey]),
      digits: data[Totp.kDigitsKey] is! int ? null : data[Totp.kDigitsKey],
      validity: data[Totp.kValidityKey] is! int ? null : Duration(seconds: data[Totp.kValidityKey]),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data[Totp.kUpdatedAtKey]),
    );
  }

  /// Converts this TOTP to a JSON compatible map.
  JsonMap toJson({bool includeUuid = true}) => {
    if (includeUuid) Totp.kUuidKey: uuid,
    ...encryptedData.toJson(),
    if (algorithm != null) Totp.kAlgorithmKey: algorithm!.name.toUpperCase(),
    if (digits != null) Totp.kDigitsKey: digits,
    if (validity != null) Totp.kValidityKey: validity!.inSeconds,
    Totp.kUpdatedAtKey: updatedAt.millisecondsSinceEpoch,
  };
}

/// Gives some useful properties for serializing encrypted data.
extension JsonEncryptedData on EncryptedData {
  /// Creates a new encrypted data from the specified JSON data.
  static EncryptedData? fromJson(JsonMap data) {
    bool bytes(Object? value) => value is List && value.every((byte) => byte is int && byte >= 0 && byte <= 255);
    if (!bytes(data[Totp.kSecretKey]) || !bytes(data[Totp.kEncryptionSaltKey]) || [Totp.kLabelKey, Totp.kIssuerKey, Totp.kImageUrlKey].any((key) => data[key] != null && !bytes(data[key]))) {
      return null;
    }
    return EncryptedData(
      encryptedSecret: Uint8List.fromList((data[Totp.kSecretKey] as List).cast<int>()),
      encryptedLabel: data[Totp.kLabelKey] is! List ? null : Uint8List.fromList((data[Totp.kLabelKey] as List).cast<int>()),
      encryptedIssuer: data[Totp.kIssuerKey] is! List ? null : Uint8List.fromList((data[Totp.kIssuerKey] as List).cast<int>()),
      encryptedImageUrl: data[Totp.kImageUrlKey] is! List ? null : Uint8List.fromList((data[Totp.kImageUrlKey] as List).cast<int>()),
      encryptionSalt: Salt.fromRawValue(value: Uint8List.fromList((data[Totp.kEncryptionSaltKey] as List).cast<int>())),
    );
  }

  /// Converts this encrypted data to a JSON compatible map.
  JsonMap toJson() => {
    Totp.kSecretKey: encryptedSecret,
    if (encryptedLabel != null) Totp.kLabelKey: encryptedLabel,
    if (encryptedIssuer != null) Totp.kIssuerKey: encryptedIssuer,
    if (encryptedImageUrl != null) Totp.kImageUrlKey: encryptedImageUrl,
    Totp.kEncryptionSaltKey: encryptionSalt.value,
  };
}
