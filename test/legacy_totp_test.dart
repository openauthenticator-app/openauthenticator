import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/crypto/salt.dart';
import 'package:open_authenticator/core/crypto/store.dart';
import 'package:open_authenticator/core/totp/decrypted.dart';
import 'package:open_authenticator/core/totp/json.dart';
import 'package:open_authenticator/core/totp/totp.dart';

/// Checks code generation for vault records written with unsupported digit counts.
void main() {
  test('unsupported stored digit counts are recovered before rendering a code', () async {
    final CryptoStore store = await CryptoStore.fromPasswordInIsolate('fixture', Salt.generate());
    final original = DecryptedTotp.create(cryptoStore: store, secret: 'JBSWY3DPEHPK3PXP', label: 'legacy')!;
    for (final digits in [16, 30, 62, 200000]) {
      final record = JsonTotp.fromJson({...original.toJson(), Totp.kDigitsKey: digits}).decrypt(store) as DecryptedTotp;
      expect(record.secret, original.secret);
      expect(record.generateCode(), matches(RegExp(r'^[0-9]{6}$')));
    }
  });
}
