import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/model/backup/backup.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/crypto/store.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/json.dart';

void main() {
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
