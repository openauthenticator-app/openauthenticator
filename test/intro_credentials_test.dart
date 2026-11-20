import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/database/database.dart';
import 'package:open_authenticator/core/secure_storage.dart';
import 'package:open_authenticator/core/settings/app_unlock_method.dart';
import 'package:open_authenticator/pages/intro/slides/slide.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// Simulates a keychain that initially refuses writes.
class _Keychain extends Fake implements CachedSimpleSecureStorage {
  /// The credentials visible to the application.
  final values = <String, String>{};

  /// Whether the keychain accepts writes.
  bool available = false;

  /// Reads a stored credential.
  @override
  String? read(String key) => values[key];

  /// Stores a credential or raises the simulated keychain error.
  @override
  Future<void> write(String key, String value, {bool flush = true}) async {
    values[key] = value;
    if (flush && !available) {
      throw StateError('keychain unavailable');
    }
  }

  /// Removes a credential when rolling back a rejected write.
  @override
  Future<void> delete(String key, {bool flush = true}) async => values.remove(key);
}

/// Checks retrying the password slide after a keychain failure.
void main() {
  test('onboarding stays on the password slide until credentials are saved', () async {
    final keychain = _Keychain();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureStorageProvider.overrideWithBuild((ref, notifier) => keychain),
        appUnlockMethodSettingsEntryProvider.overrideWithBuild((ref, notifier) => 'none'),
      ],
    );
    container.listen(currentIntroPageSlideProvider, (_, _) {});
    await container.read(currentIntroPageSlideProvider.future);
    final CurrentIntroPageSlideNotifier intro = container.read(currentIntroPageSlideProvider.notifier);
    await intro.goToNextSlide();
    final passwordSlide = await container.read(currentIntroPageSlideProvider.future) as PasswordIntroPageSlideState;
    intro.updateState(passwordSlide.overwritePassword('fixture'));
    await expectLater(intro.goToNextSlide(), throwsStateError);
    expect((await container.read(currentIntroPageSlideProvider.future)).slide, IntroPageSlide.password);
    expect(keychain.values, isEmpty);
    keychain.available = true;
    await intro.goToNextSlide();
    expect((await container.read(currentIntroPageSlideProvider.future)).slide, IntroPageSlide.logIn);
    expect(keychain.values.keys, containsAll(['passwordDerivedKeySalt', 'passwordDerivedKey']));
  });
}
