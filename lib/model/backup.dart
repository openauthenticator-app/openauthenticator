import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcrypto/webcrypto.dart';

/// The backup store provider.
final backupStoreProvider = AsyncNotifierProvider.autoDispose<BackupStore, List<Backup>>(BackupStore.new);

/// Contains all backups.
class BackupStore extends AsyncNotifier<List<Backup>> {
  /// The backup filename regex.
  static const String _kBackupFilenameRegex = r'\d{13}\.bak';

  @override
  FutureOr<List<Backup>> build() => _listBackups();

  /// Imports the [backupFile].
  Future<Result<Backup>> import(File backupFile) async {
    if (!Backup.isValidBackup(backupFile)) {
      return ResultError(exception: _InvalidBackupContentException());
    }
    DateTime? dateTime = _fromBackupFilename(backupFile);
    Backup backup = Backup._(ref: ref, dateTime: dateTime ?? DateTime.now());
    List<Backup> backups = [...(await future), backup]..sort();
    Directory directory = await getBackupsDirectory(create: true);
    backupFile.copySync(join(directory.path, backup.filename));
    if (!ref.mounted) {
      return const ResultCancelled();
    }
    state = AsyncData(backups);
    return ResultSuccess(value: backup);
  }

  /// Do a backup with the given password.
  Future<Result<Backup>> doBackup(String password) async {
    Backup backup = Backup._(ref: ref, dateTime: DateTime.now());
    Result result = await backup.save(password);
    if (result is! ResultSuccess) {
      return result.to<Backup>((value) => null);
    }
    List<Backup> backups = [...(await future), backup]..sort();
    if (!ref.mounted) {
      return const ResultCancelled();
    }
    state = AsyncData(backups);
    return ResultSuccess(value: backup);
  }

  /// Lists available backups.
  Future<List<Backup>> _listBackups() async {
    List<Backup> result = [];
    Directory directory = await getBackupsDirectory();
    if (!directory.existsSync()) {
      return result;
    }
    for (FileSystemEntity entity in directory.listSync(followLinks: false)) {
      DateTime? dateTime = _fromBackupFilename(entity);
      if (dateTime != null) {
        result.add(Backup._(ref: ref, dateTime: dateTime));
      }
    }
    return result..sort();
  }

  /// Constructs a [DateTime] from a [file], if possible.
  DateTime? _fromBackupFilename(FileSystemEntity file) {
    RegExp backupRegex = RegExp(_kBackupFilenameRegex);
    String filename = file.uri.pathSegments.last;
    if (backupRegex.hasMatch(filename)) {
      DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(filename.substring(0, filename.length - '.bak'.length)));
      return dateTime;
    }
    return null;
  }

  /// Returns the backup directory.
  static Future<Directory> getBackupsDirectory({bool create = false}) async {
    String name = '${App.appName} Backups${kDebugMode ? ' (Debug)' : ''}';
    Directory directory = Directory(join((await getApplicationDocumentsDirectory()).path, name));
    if (create && !directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}

/// Represents a backup of a list of TOTPs.
class Backup implements Comparable<Backup> {
  /// The TOTPs JSON key.
  static const String kTotpsKey = 'totps';

  /// The salt JSON key.
  static const String kSaltKey = 'salt';

  /// The password signature JSON key.
  static const String kPasswordSignatureKey = 'passwordSignature';

  /// The Riverpod ref.
  final Ref _ref;

  /// The backup time.
  final DateTime dateTime;

  /// Creates a new backup instance.
  Backup._({
    required Ref ref,
    required this.dateTime,
  }) : _ref = ref;

  /// Returns whether the given [file] is a valid backup file.
  static bool isValidBackup(File file) {
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

  /// Restore this backup.
  Future<Result> restore(String password) async {
    try {
      File file = await getBackupPath();
      if (!file.existsSync()) {
        throw _BackupFileDoesNotExistException(path: file.path);
      }

      if (!isValidBackup(file)) {
        throw _InvalidBackupContentException();
      }

      Map<String, dynamic> jsonData = jsonDecode(file.readAsStringSync());
      CryptoStore cryptoStore = await CryptoStore.fromPassword(password, Salt.fromRawValue(value: base64.decode(jsonData[kSaltKey])));
      HmacSecretKey hmacSecretKey = await HmacSecretKey.importRawKey(await cryptoStore.key.exportRawKey(), Hash.sha256);
      if (!(await hmacSecretKey.verifyBytes(base64.decode(jsonData[kPasswordSignatureKey]), utf8.encode(password)))) {
        throw InvalidPasswordException();
      }

      CryptoStore? currentCryptoStore = await _ref.read(cryptoStoreProvider.future);
      if (currentCryptoStore == null) {
        throw _CryptoError();
      }

      List jsonTotps = jsonData[kTotpsKey];
      List<Totp> totps = [];
      for (dynamic jsonTotp in jsonTotps) {
        Totp? totp = JsonTotp.tryFromJson(jsonTotp);
        if (totp != null) {
          DecryptedTotp? decryptedTotp = await totp.changeEncryptionKey(cryptoStore, currentCryptoStore);
          totps.add(decryptedTotp ?? totp);
        }
      }
      if (totps.isEmpty && jsonTotps.isNotEmpty) {
        throw InvalidPasswordException();
      }
      return await _ref.read(totpRepositoryProvider.notifier).replaceBy(totps);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Saves this backup.
  Future<Result> save(String password) async {
    try {
      CryptoStore? currentCryptoStore = await _ref.read(cryptoStoreProvider.future);
      if (currentCryptoStore == null) {
        throw _CryptoError();
      }
      CryptoStore newStore = await CryptoStore.fromPassword(password, await Salt.generate());
      List<Totp> totps = await _ref.read(totpRepositoryProvider.future);
      List<Totp> toBackup = [];
      for (Totp totp in totps) {
        DecryptedTotp? decryptedTotp = await totp.changeEncryptionKey(currentCryptoStore, newStore);
        toBackup.add(decryptedTotp ?? totp);
      }
      HmacSecretKey hmacSecretKey = await HmacSecretKey.importRawKey(await newStore.key.exportRawKey(), Hash.sha256);
      File file = await getBackupPath(createDirectory: true);
      await file.writeAsString(
        jsonEncode({
          kPasswordSignatureKey: base64.encode(await hmacSecretKey.signBytes(utf8.encode(password))),
          kSaltKey: base64.encode(newStore.salt.value),
          kTotpsKey: [
            for (Totp totp in toBackup) totp.toJson(),
          ],
        }),
      );
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes this backup.
  Future<Result> delete() async {
    try {
      File file = await getBackupPath();
      if (file.existsSync()) {
        file.deleteSync();
      }
      _ref.invalidateSelf();
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Returns the backup filename.
  String get filename => '${dateTime.millisecondsSinceEpoch}.bak';

  /// Returns the backup path (TOTPs and salt).
  Future<File> getBackupPath({bool createDirectory = false}) async {
    Directory directory = await BackupStore.getBackupsDirectory(create: createDirectory);
    return File(join(directory.path, filename));
  }

  @override
  int compareTo(Backup other) => other.dateTime.compareTo(dateTime);
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
class InvalidPasswordException extends LocalizableException {
  /// Creates a new invalid password exception instance.
  InvalidPasswordException()
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

/// Thrown when there is an encryption error.
class _CryptoError extends LocalizableException {
  /// Creates a new crypto error instance.
  _CryptoError()
    : super(
        localizedErrorMessage: translations.error.backup.crypto,
      );
}
