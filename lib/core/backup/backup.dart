import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/core/crypto/salt.dart';
import 'package:open_authenticator/core/crypto/store.dart';
import 'package:open_authenticator/core/totp/decrypted.dart';
import 'package:open_authenticator/core/totp/json.dart';
import 'package:open_authenticator/core/totp/repository.dart';
import 'package:open_authenticator/core/totp/totp.dart';
import 'package:open_authenticator/core/totp/undecryptable.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/json.dart';
import 'package:open_authenticator/utils/result/reporter.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

part 'path.dart';
part 'store.dart';

/// Represents a backup of a list of TOTPs.
class Backup implements Comparable<Backup> {
  /// The TOTPs JSON key.
  static const String kTotpsKey = 'totps';

  /// The salt JSON key.
  static const String kSaltKey = 'salt';

  /// The password signature JSON key.
  static const String kPasswordSignatureKey = 'passwordSignature';

  /// The length in bytes of an HMAC-SHA-256 backup password signature.
  static const int _signatureLength = 256 ~/ 8;

  /// The backup path.
  final BackupPath backupPath;

  /// The backup password signature.
  final String passwordSignature;

  /// The backup salt.
  final Salt salt;

  /// The backup TOTPs.
  final List<Totp> totps;

  /// Creates a new backup instance.
  const Backup._({
    required this.backupPath,
    required this.passwordSignature,
    required this.salt,
    this.totps = const [],
  });

  /// Returns the backup date.
  DateTime get dateTime => backupPath.timestamp;

  /// Reads the backup envelope and checks its required fields.
  static Future<({List totps, Salt salt, Uint8List signature})> _readContent(File file) async {
    if (!await file.exists()) {
      throw _BackupFileDoesNotExistException(path: file.path);
    }
    try {
      final Object? data = jsonDecode(utf8.decode(await file.readAsBytes()));
      if (data case {kTotpsKey: final List totps, kSaltKey: final String encodedSalt, kPasswordSignatureKey: final String encodedSignature}) {
        final salt = Salt.base64Decode(string: encodedSalt);
        final Uint8List signature = base64.decode(encodedSignature);
        // Argon2 requires a salt of at least eight bytes.
        if (salt.value.length >= 8 && signature.length == _signatureLength) {
          return (totps: totps, salt: salt, signature: signature);
        }
      }
    } on FormatException {
      throw _InvalidBackupContentException();
    }
    throw _InvalidBackupContentException();
  }

  /// Encrypts [totps] with a new backup key, including an empty vault during setup.
  static Future<Backup> _create(String password, CryptoStore? currentCryptoStore, List<Totp> totps) async {
    if (currentCryptoStore == null && totps.isNotEmpty) {
      throw _CryptoError();
    }
    final CryptoStore newStore = await CryptoStore.fromPasswordInIsolate(password, Salt.generate());
    final List<Totp> toBackup = [];
    final List<String> undecryptable = [];
    for (final Totp totp in totps) {
      final DecryptedTotp? decryptedTotp = totp.changeEncryptionKey(currentCryptoStore!, newStore);
      if (decryptedTotp == null) {
        undecryptable.add(totp.uuid);
      } else {
        toBackup.add(decryptedTotp);
      }
    }
    if (undecryptable.isNotEmpty) {
      throw UndecryptableTotpsException(undecryptable);
    }
    return Backup._(
      backupPath: await BackupPath.create(),
      passwordSignature: newStore.hmacSecretKey.string(password, utf8).base64(),
      salt: newStore.salt,
      totps: toBackup,
    );
  }

  /// Read the backup content from the given file.
  static Future<Backup> _read(BackupPath backupPath, CryptoStore currentCryptoStore, String password) async {
    final File file = backupPath.file;
    final (totps: List entries, :Salt salt, :Uint8List signature) = await _readContent(file);
    final CryptoStore cryptoStore = await CryptoStore.fromPasswordInIsolate(password, salt);
    if (!cryptoStore.hmacSecretKey.verify(signature, utf8.encode(password))) {
      throw InvalidBackupPasswordException();
    }

    final List<Totp> totps = [];
    final uuids = <String>{};
    final int defaultUpdatedAt = (await file.lastModified()).millisecondsSinceEpoch;
    for (final dynamic jsonTotp in entries) {
      if (jsonTotp is! JsonMap) {
        throw _InvalidBackupContentException();
      }
      if (jsonTotp[Totp.kUpdatedAtKey] == null) {
        jsonTotp[Totp.kUpdatedAtKey] = defaultUpdatedAt;
      }
      final Totp? totp = JsonTotp.tryFromJson(jsonTotp);
      if (totp == null || !uuids.add(totp.uuid)) {
        throw _InvalidBackupContentException();
      }
      final Totp original = totp.decrypt(cryptoStore);
      if (original is! DecryptedTotp) {
        throw _InvalidBackupContentException();
      }
      final DecryptedTotp? decrypted = original.changeEncryptionKey(cryptoStore, currentCryptoStore);
      if (decrypted == null) {
        throw _InvalidBackupContentException();
      }
      totps.add(decrypted);
    }
    return Backup._(
      backupPath: backupPath,
      passwordSignature: base64.encode(signature),
      salt: cryptoStore.salt,
      totps: totps,
    );
  }

  /// Restores this backup content.
  Future<Result<List<Totp>>> restore(TotpRepository totpRepository) => totpRepository.replaceBy(totps);

  /// Saves this backup content.
  Future<void> save() async {
    try {
      await backupPath.file.writeAsString(
        jsonEncode({
          kPasswordSignatureKey: passwordSignature,
          kSaltKey: base64.encode(salt.value),
          kTotpsKey: [for (final Totp totp in totps) totp.toJson()],
        }),
        flush: true,
      );
    } catch (_) {
      await backupPath.delete();
      rethrow;
    }
  }

  /// Deletes this backup.
  Future<void> delete() => backupPath.delete();

  @override
  int compareTo(Backup other) => other.backupPath.compareTo(backupPath);
}

/// Thrown when the file does not exist.
class _BackupFileDoesNotExistException extends LocalizableException {
  /// Creates a new backup file doesn't exist exception instance.
  _BackupFileDoesNotExistException({
    required String path,
  }) : super(
         localizedErrorMessage: translations.error.backup.fileDoesNotExist(path: path),
       );
}

/// Thrown when an invalid password has been provided.
class InvalidBackupPasswordException extends LocalizableException with UserError {
  /// Creates a new invalid password exception instance.
  InvalidBackupPasswordException()
    : super(
        localizedErrorMessage: translations.error.backup.invalidPassword,
      );
}

/// Thrown when the backup content is invalid.
class _InvalidBackupContentException extends LocalizableException with UserError {
  /// Creates a new invalid backup content exception instance.
  _InvalidBackupContentException()
    : super(
        localizedErrorMessage: translations.error.backup.invalidContent,
      );
}
