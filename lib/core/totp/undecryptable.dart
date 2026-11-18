import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/result/reporter.dart';

/// Thrown when an operation requires all TOTPs to be decrypted, but some of them cannot be.
/// The user can decrypt them from the TOTPs list (using the password that was used to encrypt them), or delete them.
class UndecryptableTotpsException extends LocalizableException with UserError {
  /// The UUIDs of the TOTPs that cannot be decrypted.
  final List<String> uuids;

  /// Creates a new undecryptable TOTPs exception instance.
  UndecryptableTotpsException(this.uuids)
    : super(
        localizedErrorMessage: translations.error.totp.undecryptable(count: uuids.length),
      );
}
