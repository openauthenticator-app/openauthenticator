import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/crypto/derived_key.dart';
import 'package:open_authenticator/core/crypto/salt.dart';
import 'package:open_authenticator/core/crypto/store.dart';
import 'package:open_authenticator/core/database/database.dart';
import 'package:open_authenticator/core/secure_storage.dart';
import 'package:open_authenticator/core/settings/app_unlock_method.dart';
import 'package:open_authenticator/core/settings/storage_type.dart';
import 'package:open_authenticator/core/totp/decrypted.dart';
import 'package:open_authenticator/core/totp/repository.dart';
import 'package:open_authenticator/core/totp/totp.dart';
import 'package:open_authenticator/core/totp/undecryptable.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

class _FailingStorage extends Fake implements CachedSimpleSecureStorage {
  _FailingStorage(CryptoStore store)
    : values = {
        'passwordDerivedKey': base64.encode(store.key.value),
        'passwordDerivedKeySalt': base64.encode(store.salt.value),
      };

  final Map<String, String> values;

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String value, {bool flush = true}) async {
    values[key] = value;
    if (flush) {
      throw StateError('credential store unavailable');
    }
  }
}

void main() {
  test('a failed credential write preserves the original key, ciphertext and outbox', () async {
    final CryptoStore original = await CryptoStore.fromPasswordInIsolate('old password', Salt.generate());
    final storage = _FailingStorage(original);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final Totp record = DecryptedTotp.create(cryptoStore: original, secret: 'JBSWY3DPEHPK3PXP', label: 'fixture')!;
    await db.saveTotps([record]);
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureStorageProvider.overrideWithBuild((ref, notifier) => storage),
        appUnlockMethodSettingsEntryProvider.overrideWithBuild((ref, notifier) => 'none'),
        storageTypeSettingsEntryProvider.overrideWithBuild((ref, notifier) => StorageType.shared),
      ],
    );
    container.listen(totpRepositoryProvider, (_, _) {});
    final Result<String> result = await container.read(totpRepositoryProvider.notifier).changeMasterPassword('new password');
    expect(result, isA<ResultError<String>>());
    expect((result as ResultError<String>).exception.toString(), contains('credential store unavailable'));
    expect(await container.read(derivedKeyProvider.future), original.key);
    expect(storage.read('passwordDerivedKey'), base64.encode(original.key.value));
    expect((await db.listTotps()).single.encryptedData.encryptedSecret, record.encryptedData.encryptedSecret);
    expect(await db.listPendingBackendPushOperations(), isEmpty);
  });

  test('an undecryptable TOTP aborts the password change and is reported', () async {
    final CryptoStore original = await CryptoStore.fromPasswordInIsolate('old password', Salt.generate());
    final CryptoStore foreign = await CryptoStore.fromPasswordInIsolate('another password', Salt.generate());
    final storage = _FailingStorage(original);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final Totp readable = DecryptedTotp.create(cryptoStore: original, secret: 'JBSWY3DPEHPK3PXP', label: 'readable')!;
    final Totp unreadable = DecryptedTotp.create(cryptoStore: foreign, secret: 'JBSWY3DPEHPK3PXP', label: 'unreadable')!;
    await db.saveTotps([readable, unreadable]);
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureStorageProvider.overrideWithBuild((ref, notifier) => storage),
        appUnlockMethodSettingsEntryProvider.overrideWithBuild((ref, notifier) => 'none'),
        storageTypeSettingsEntryProvider.overrideWithBuild((ref, notifier) => StorageType.shared),
      ],
    );
    container.listen(totpRepositoryProvider, (_, _) {});
    final Result<String> result = await container.read(totpRepositoryProvider.notifier).changeMasterPassword('new password');
    expect(result, isA<ResultError<String>>());
    final Object exception = (result as ResultError<String>).exception;
    expect(exception, isA<UndecryptableTotpsException>());
    expect((exception as UndecryptableTotpsException).uuids, [unreadable.uuid]);
    expect(await container.read(derivedKeyProvider.future), original.key);
    expect(
      {for (final Totp totp in await db.listTotps()) totp.uuid: totp.encryptedData.encryptedSecret},
      {
        readable.uuid: readable.encryptedData.encryptedSecret,
        unreadable.uuid: unreadable.encryptedData.encryptedSecret,
      },
    );
    expect(await db.listPendingBackendPushOperations(), isEmpty);
  });
}
