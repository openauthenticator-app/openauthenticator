import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/backup/backup.dart';
import 'package:open_authenticator/core/crypto/salt.dart';
import 'package:open_authenticator/core/crypto/store.dart';
import 'package:open_authenticator/core/totp/decrypted.dart';
import 'package:open_authenticator/core/totp/json.dart';
import 'package:open_authenticator/core/totp/repository.dart';
import 'package:open_authenticator/core/totp/totp.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/utils/json.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Supplies private backup directories for each test.
class _BackupDirectories extends PathProviderPlatform {
  /// The temporary root of the test file system.
  final Directory root;

  /// Creates a path provider rooted in [root].
  _BackupDirectories(this.root);

  /// Returns the directory for application-managed backups.
  @override
  Future<String> getApplicationSupportPath() async => '${root.path}/support';

  /// Returns the directory for user-managed documents.
  @override
  Future<String> getApplicationDocumentsPath() async => '${root.path}/documents';
}

/// Checks encrypted backup creation, restoration and removal.
void main() {
  test('first-time setup can back up an empty vault and delete multiple listed backups', () async {
    final Directory root = await Directory.systemTemp.createTemp('backup-setup-');
    addTearDown(() => root.delete(recursive: true));
    final PathProviderPlatform previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _BackupDirectories(root);
    addTearDown(() => PathProviderPlatform.instance = previous);
    final container = ProviderContainer.test(
      overrides: [
        cryptoStoreProvider.overrideWithBuild((ref, notifier) => null),
        totpRepositoryProvider.overrideWithBuild((ref, notifier) => []),
      ],
    );
    container.listen(backupStoreProvider, (_, _) {});
    final BackupStore store = container.read(backupStoreProvider.notifier);
    final Result<Backup> first = await store.doBackup('fixture');
    expect(first, isA<ResultSuccess<Backup>>());
    final CryptoStore key = await CryptoStore.fromPasswordInIsolate('device', Salt.generate());
    expect((await first.valueOrNull!.backupPath.read(key, 'fixture')).totps, isEmpty);
    expect(await store.doBackup('second fixture'), isA<ResultSuccess<Backup>>());
    final List<BackupPath> snapshots = await container.read(backupStoreProvider.future);
    expect(snapshots, hasLength(2));
    for (final backup in snapshots) {
      expect(await store.deleteBackup(backup), isA<ResultSuccess>());
    }
    expect(await BackupPath.list().toList(), isEmpty);
  });

  test('backup restore validates every entry before returning the vault', () async {
    final Directory directory = await Directory.systemTemp.createTemp('open-authenticator-backup-');
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/1700000000000.bak');
    const password = 'backup password';
    final CryptoStore store = await CryptoStore.fromPasswordInIsolate(password, Salt.generate());
    final CryptoStore current = await CryptoStore.fromPasswordInIsolate('device password', Salt.generate());
    JsonMap entry(CryptoStore key) => DecryptedTotp.create(cryptoStore: key, secret: 'JBSWY3DPEHPK3PXP', label: 'Fixture')!.toJson();
    final JsonMap valid = entry(store);
    Future<Backup> read(List<Object?> entries) async {
      await file.writeAsString(
        jsonEncode({
          Backup.kTotpsKey: entries,
          Backup.kSaltKey: base64.encode(store.salt.value),
          Backup.kPasswordSignatureKey: store.hmacSecretKey.string(password, utf8).base64(),
        }),
      );
      return BackupPath.fromPath(path: file.path)!.read(current, password);
    }

    for (final List<int> invalid in [
      [0xff, 0xfe],
      utf8.encode('{'),
    ]) {
      await file.writeAsBytes(invalid);
      await expectLater(BackupPath.fromPath(path: file.path)!.read(current, password), throwsA(isA<LocalizableException>()));
    }
    final Backup restored = await read([valid]);
    expect((restored.totps.single as DecryptedTotp).secret, 'JBSWY3DPEHPK3PXP');
    expect(restored.totps.single.encryptedData.encryptionSalt, current.salt);
    for (final Object? broken in [
      null,
      valid,
      entry(current),
      {...valid, Totp.kUuidKey: 'other', Totp.kValidityKey: 0},
    ]) {
      await expectLater(read([valid, broken]), throwsA(isA<LocalizableException>()));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
