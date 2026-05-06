import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/crypto/store.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
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

  /// Returns whether the given [file] is a valid backup file.
  static bool _isBackupFileContentValid(File file) {
    if (!file.existsSync()) {
      return false;
    }
    try {
      Map<String, dynamic> jsonData = jsonDecode(file.readAsStringSync());
      return jsonData[kTotpsKey] is List && jsonData[kSaltKey] is String && jsonData[kPasswordSignatureKey] is String;
    } on FormatException {
      return false;
    }
  }

  static Future<Backup> _create(String password, CryptoStore currentCryptoStore, List<Totp> totps) async {
    CryptoStore newStore = CryptoStore.fromPassword(password, Salt.generate());
    List<Totp> toBackup = [];
    for (Totp totp in totps) {
      DecryptedTotp? decryptedTotp = totp.changeEncryptionKey(currentCryptoStore, newStore);
      toBackup.add(decryptedTotp ?? totp);
    }
    return Backup._(
      backupPath: await BackupPath.create(),
      passwordSignature: newStore.hmacSecretKey.string(password, utf8).base64(),
      salt: newStore.salt,
      totps: toBackup,
    );
  }

  /// Read the backup content from the given file.
  static Backup _read(BackupPath backupPath, CryptoStore currentCryptoStore, String password) {
    File file = backupPath.file;
    if (!file.existsSync()) {
      throw _BackupFileDoesNotExistException(path: file.path);
    }

    if (!_isBackupFileContentValid(file)) {
      throw _InvalidBackupContentException();
    }

    Map<String, dynamic> jsonData = jsonDecode(file.readAsStringSync());
    CryptoStore cryptoStore = CryptoStore.fromPassword(password, Salt.base64Decode(string: jsonData[kSaltKey]));
    if (!(cryptoStore.hmacSecretKey.verify(base64.decode(jsonData[kPasswordSignatureKey]), utf8.encode(password)))) {
      throw InvalidBackupPasswordException();
    }

    List jsonTotps = jsonData[kTotpsKey];
    List<Totp> totps = [];
    int defaultUpdatedAt = file.lastModifiedSync().millisecondsSinceEpoch;
    for (dynamic jsonTotp in jsonTotps) {
      if (jsonTotp is! Map<String, dynamic>) {
        continue;
      }
      if (jsonTotp[Totp.kUpdatedAtKey] == null) {
        jsonTotp[Totp.kUpdatedAtKey] = defaultUpdatedAt;
      }
      Totp? totp = JsonTotp.tryFromJson(jsonTotp);
      if (totp != null) {
        DecryptedTotp? decryptedTotp = totp.changeEncryptionKey(cryptoStore, currentCryptoStore);
        totps.add(decryptedTotp ?? totp);
      }
    }
    if (totps.isEmpty && jsonTotps.isNotEmpty) {
      throw InvalidBackupPasswordException();
    }
    Map<String, dynamic> backupData = jsonDecode(file.readAsStringSync());
    return Backup._(
      backupPath: BackupPath.fromPath(path: file.path)!,
      passwordSignature: backupData[kPasswordSignatureKey],
      salt: Salt.base64Decode(string: backupData[kSaltKey]),
      totps: totps,
    );
  }

  /// Restores this backup content.
  Future<Result<List<Totp>>> restore(TotpRepository totpRepository) => totpRepository.replaceBy(totps);

  /// Saves this backup content.
  Future<void> save() async {
    File file = await backupPath.createFile();
    await file.writeAsString(
      jsonEncode({
        kPasswordSignatureKey: passwordSignature,
        kSaltKey: base64.encode(salt.value),
        kTotpsKey: [
          for (Totp totp in totps) totp.toJson(),
        ],
      }),
    );
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
class InvalidBackupPasswordException extends LocalizableException {
  /// Creates a new invalid password exception instance.
  InvalidBackupPasswordException()
    : super(
        localizedErrorMessage: translations.error.backup.invalidPassword,
      );
}

/// Thrown when the backup content is invalid.
class _InvalidBackupContentException extends LocalizableException {
  /// Creates a new invalid backup content exception instance.
  _InvalidBackupContentException()
    : super(
        localizedErrorMessage: translations.error.backup.invalidContent,
      );
}
