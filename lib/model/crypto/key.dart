import 'dart:convert';

import 'package:cipherlib/cipherlib.dart';
import 'package:flutter/foundation.dart';
import 'package:hashlib/hashlib.dart';
import 'package:hashlib/random.dart';

/// Represents a crypto key.
class CryptoKey {
  /// The key value.
  final Uint8List value;

  /// Creates a new key instance using the [value].
  const CryptoKey.fromRawValue({
    required this.value,
  });

  /// Creates a new key instance using the Base 64 encoded [string].
  CryptoKey.base64Decode({
    required String string,
  }) : this.fromRawValue(
         value: base64.decode(string),
       );

  /// Generates a random key.
  CryptoKey.generate(int length)
    : this.fromRawValue(
        value: randomBytes(length),
      );

  /// Returns the [AES] instance corresponding to the [value].
  AES get aes => AES(value);

  /// Returns the HMAC secret key corresponding to the [value].
  MACHashBase get hmacSecretKey => sha256.hmac.by(value);

  @override
  String toString() => base64.encode(value);

  @override
  bool operator ==(Object other) {
    if (other is! CryptoKey) {
      return super == other;
    }
    return identical(this, other) || listEquals(value, other.value);
  }

  @override
  int get hashCode => Object.hashAll(value);
}
