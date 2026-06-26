import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/shared_preferences_with_prefix.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The secure storage provider.
final secureStorageProvider = AsyncNotifierProvider<SecureStorageNotifier, CachedSimpleSecureStorage>(SecureStorageNotifier.new);

/// Allows to initialize [SimpleSecureStorage] with parameters that depend on the current platform.
class SecureStorageNotifier extends AsyncNotifier<CachedSimpleSecureStorage> {
  /// The timeout used to initialize [SimpleSecureStorage].
  static const Duration _kInitializationTimeout = Duration(seconds: 10);

  @override
  FutureOr<CachedSimpleSecureStorage> build() async {
    InitializationOptions options = switch (currentPlatform) {
      .iOS || .macOS => _OpenAuthenticatorSSSDarwinInitializationOptions(),
      _ => _OpenAuthenticatorSSSInitializationOptions(),
    };
    CachedSimpleSecureStorage storage;
    try {
      storage = await CachedSimpleSecureStorage.getInstance(options).timeout(_kInitializationTimeout);
    } catch (ex) {
      if (!_StorageRecovery.shouldRecoverFrom(ex)) {
        rethrow;
      }
      await _StorageRecovery.clearRestoredEncryptedSharedPreferences(ref);
      storage = await CachedSimpleSecureStorage.getInstance(options).timeout(_kInitializationTimeout);
    }
    return storage;
  }
}

/// Allows to clear the restored encrypted storage.
class _StorageRecovery {
  /// The channel used to communicate with the native platform.
  static const MethodChannel _channel = MethodChannel('app.openauthenticator.storage_recovery');

  /// Returns `true` if the device is running Android.
  static bool get isAvailable => currentPlatform == .android;

  /// Returns whether [ex] is compatible with unrestorable Android encrypted preferences.
  static bool shouldRecoverFrom(Object ex) {
    if (!isAvailable || ex is! PlatformException || ex.code != 'operation_failed') {
      return false;
    }
    String error = [
      ex.message,
      ex.details,
    ].whereType<Object>().join('\n').toLowerCase();
    return const [
      'aeadbadtagexception',
      'badpaddingexception',
      'could not decrypt',
      'decryption failed',
      'failed to decrypt',
      'invalid mac',
      'invalidkeyexception',
      'invalidprotocolbufferexception',
      'invalid keyset',
      'key not found',
      'keyset',
      'keypermanentlyinvalidatedexception',
      'keystore',
      'keystore operation failed',
      'mac verification failed',
      'unrecoverablekeyexception',
    ].any(error.contains);
  }

  /// Clears the restored encrypted shared preferences.
  static Future<void> clearRestoredEncryptedSharedPreferences(Ref ref) async {
    await _channel.invokeMethod('clearRestoredEncryptedSharedPreferences');
    SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.remove(AppUnlockMethodSettingsEntry.kKey);
    ref.invalidate(appUnlockMethodSettingsEntryProvider);
  }
}

/// Allows to initialize [SimpleSecureStorage] with parameters that depend on the current mode.
class _OpenAuthenticatorSSSInitializationOptions extends InitializationOptions {
  /// Creates a new Open Authenticator SimpleSecureStorage initialization options.
  _OpenAuthenticatorSSSInitializationOptions()
    : super(
        appName: App.appName + (kDebugMode ? ' Debug' : ''),
        namespace: App.appPackageName + (kDebugMode ? '.debug' : ''),
      );
}

/// Allows to initialize [SimpleSecureStorage] on Darwin platforms with parameters that depend on the current mode.
class _OpenAuthenticatorSSSDarwinInitializationOptions extends DarwinInitializationOptions {
  /// Creates a new Open Authenticator SimpleSecureStorage initialization options.
  _OpenAuthenticatorSSSDarwinInitializationOptions()
    : super(
        appName: App.appName + (kDebugMode ? ' Debug' : ''),
        namespace: App.appPackageName + (kDebugMode ? '.debug' : ''),
        accessibility: .afterFirstUnlock,
      );
}
