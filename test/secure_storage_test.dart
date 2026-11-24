import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/secure_storage.dart';
import 'package:open_authenticator/utils/result/reporter.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// Simulates a keychain that refuses writes with the given [error].
class _FailingKeychain extends Fake implements CachedSimpleSecureStorage {
  /// The error thrown by the platform when flushing a write.
  final PlatformException error;

  /// The credentials visible to the application.
  final values = <String, String>{'existing': 'previous'};

  /// Creates a keychain failing with [error].
  _FailingKeychain(this.error);

  /// Reads a stored credential.
  @override
  String? read(String key) => values[key];

  /// Stores a credential, then raises the simulated platform error.
  @override
  Future<void> write(String key, String value, {bool flush = true}) async {
    values[key] = value;
    if (flush) {
      throw error;
    }
  }

  /// Removes a credential when rolling back a rejected write.
  @override
  Future<void> delete(String key, {bool flush = true}) async => values.remove(key);
}

/// Checks how credential write failures are surfaced.
void main() {
  test('keychain write errors become localized user errors and keep the previous values', () async {
    final keychain = _FailingKeychain(PlatformException(code: 'write_error', message: 'Error while writing data.', details: -25308));
    for (final String key in ['existing', 'new']) {
      await expectLater(
        keychain.writeCredential(key, 'value'),
        throwsA(
          isA<SecureStorageWriteException>()
              .having((error) => error.localizedErrorMessage, 'localizedErrorMessage', contains('Error while writing data.'))
              .having(isReportableException, 'isReportableException', isFalse),
        ),
      );
    }
    expect(keychain.values, {'existing': 'previous'});
  });

  test('other secure storage errors are still reported', () async {
    final keychain = _FailingKeychain(PlatformException(code: 'unknown_error'));
    await expectLater(keychain.writeCredential('new', 'value'), throwsA(isA<PlatformException>().having(isReportableException, 'isReportableException', isTrue)));
    expect(keychain.values, {'existing': 'previous'});
  });
}
