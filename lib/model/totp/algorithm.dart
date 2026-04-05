import 'package:hashlib/hashlib.dart' as hashlib;
import 'package:open_authenticator/utils/utils.dart';

/// Allows to avoid conflicts with [totp_lib.Algorithm].
enum Algorithm {
  /// The SHA1 algorithm.
  sha1(hashlib.sha1),

  /// The SHA256 algorithm.
  sha256(hashlib.sha256),

  /// The SHA512 algorithm.
  sha512(hashlib.sha512)
  ;

  /// The corresponding [totp_lib.Algorithm] enum entry.
  final hashlib.BlockHashBase mapsTo;

  /// Creates a new algorithm instance.
  const Algorithm(this.mapsTo);

  /// Tries to convert the given [string] to an [Algorithm].
  static Algorithm? fromString(String string) => Algorithm.values.firstWhereOrNull((algorithm) => algorithm.name.toLowerCase() == string);
}
