import 'package:open_authenticator/model/totp/algorithm.dart';
import 'package:open_authenticator/utils/uri_builder.dart';

/// Handles `otpauth://totp/` links.
extension type OtpAuthTotpLink(Uri uri) implements Uri {
  /// The scheme.
  static const String _kScheme = 'otpauth';

  /// The host.
  static const String _kHost = 'totp';

  /// The secret key.
  static const String _kSecretKey = 'secret';

  /// The issuer key.
  static const String _kIssuerKey = 'issuer';

  /// The algorithm key.
  static const String _kAlgorithmKey = 'algorithm';

  /// The digits key.
  static const String _kDigitsKey = 'digits';

  /// The period key.
  static const String _kPeriodKey = 'period';

  /// Creates a new TOTP URI from the given parameters.
  factory OtpAuthTotpLink.build({
    required String secret,
    String? label,
    String? issuer,
    Algorithm? algorithm,
    int? digits,
    Duration? validity,
  }) {
    UriBuilder builder = UriBuilder(
      scheme: _kScheme,
      host: _kHost,
      path: label,
    );
    builder.appendQueryParameter(_kSecretKey, secret);
    if (issuer != null) {
      builder.appendQueryParameter(_kIssuerKey, issuer);
    }
    if (algorithm != null) {
      builder.appendQueryParameter(_kAlgorithmKey, algorithm.name.toLowerCase());
    }
    if (digits != null) {
      builder.appendQueryParameter(_kDigitsKey, digits.toString());
    }
    if (validity != null) {
      builder.appendQueryParameter(_kPeriodKey, validity.inSeconds.toString());
    }
    return OtpAuthTotpLink(builder.build());
  }

  /// Returns whether the current [uri] is a valid TOTP URI.
  bool get isValid => uri.isScheme(_kScheme) && uri.host == _kHost && uri.queryParameters.containsKey(_kSecretKey);

  /// Returns the encoded secret.
  String get encodedSecret => uri.queryParameters[_kSecretKey]!;

  /// Returns the decoded secret.
  String get label {
    String label = Uri.decodeFull(uri.path);
    if (label.startsWith('/')) {
      label = label.substring(1);
    }
    return label;
  }

  /// Returns the issuer.
  String? get issuer => uri.queryParameters[_kIssuerKey];

  /// Returns the algorithm.
  Algorithm? get algorithm => uri.queryParameters.containsKey(_kAlgorithmKey) ? Algorithm.fromString(uri.queryParameters[_kAlgorithmKey]!) : null;

  /// Returns the digits.
  int? get digits => uri.queryParameters.containsKey(_kDigitsKey) ? int.tryParse(uri.queryParameters[_kDigitsKey]!) : null;

  /// Returns the validity.
  Duration? get validity {
    int? validity = uri.queryParameters.containsKey(_kPeriodKey) ? int.tryParse(uri.queryParameters[_kPeriodKey]!) : null;
    return validity == null ? null : Duration(seconds: validity);
  }
}
