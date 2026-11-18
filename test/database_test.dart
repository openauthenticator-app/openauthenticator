import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/totp/totp.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Totp createTotp(String uuid) => Totp(
    uuid: uuid,
    encryptedData: EncryptedData(
      encryptedSecret: Uint8List.fromList([1, 2, 3]),
      encryptedLabel: Uint8List.fromList([4]),
      encryptionSalt: Salt.fromRawValue(value: Uint8List.fromList([5, 6])),
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  );

  test('markAsDeleted only keeps the newest tombstones', () async {
    await database.markAsDeleted({
      'a': DateTime.fromMillisecondsSinceEpoch(2000),
      'b': DateTime.fromMillisecondsSinceEpoch(2000),
    });
    await database.markAsDeleted({
      'a': DateTime.fromMillisecondsSinceEpoch(1000),
      'b': DateTime.fromMillisecondsSinceEpoch(3000),
      'c': DateTime.fromMillisecondsSinceEpoch(1000),
    });
    expect(await database.getDeletedTotps(), {
      'a': DateTime.fromMillisecondsSinceEpoch(2000),
      'b': DateTime.fromMillisecondsSinceEpoch(3000),
      'c': DateTime.fromMillisecondsSinceEpoch(1000),
    });
  });

  test('deleteTotps deletes and marks TOTPs as deleted', () async {
    await database.addTotps([createTotp('a'), createTotp('b')]);
    await database.deleteTotps({'a': DateTime.fromMillisecondsSinceEpoch(5000)});
    expect((await database.listTotps()).map((totp) => totp.uuid), ['b']);
    expect(await database.getDeletedTotps(), {'a': DateTime.fromMillisecondsSinceEpoch(5000)});
  });

  test('replaceTotps replaces TOTPs and tombstones', () async {
    await database.addTotps([createTotp('a'), createTotp('b')]);
    await database.markAsDeleted({'c': DateTime.fromMillisecondsSinceEpoch(1000)});
    await database.replaceTotps([createTotp('c')], {'a': DateTime.fromMillisecondsSinceEpoch(4000)});
    expect((await database.listTotps()).map((totp) => totp.uuid), ['c']);
    expect(await database.getDeletedTotps(), {'a': DateTime.fromMillisecondsSinceEpoch(4000)});
  });
}
