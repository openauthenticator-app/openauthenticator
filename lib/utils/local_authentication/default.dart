import 'package:local_auth/local_auth.dart' as local_auth;
// ignore: depend_on_referenced_packages
import 'package:local_auth_android/local_auth_android.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_darwin/local_auth_darwin.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_darwin/types/auth_messages_macos.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/utils/local_authentication/local_authentication.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

/// Uses Flutter's LocalAuthentication implementation.
class LocalAuthenticationDefault extends LocalAuthentication {
  /// The [local_auth.LocalAuthentication] instance.
  final local_auth.LocalAuthentication _localAuthentication;

  /// Creates a new default local authentication instance.
  LocalAuthenticationDefault() : _localAuthentication = local_auth.LocalAuthentication();

  @override
  Future<bool> authenticate(UnlockReason reason) async {
    if (currentPlatform.isDesktop) {
      await windowManager.ensureInitialized();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
    }
    bool result = await _localAuthentication.authenticate(
      localizedReason: translations.appUnlock.localAuthentication[reason.name] ?? 'Authenticate to access the app.',
      authMessages: [
        IOSAuthMessages(
          cancelButton: translations.appUnlock.button.cancel,
        ),
        MacOSAuthMessages(
          cancelButton: translations.appUnlock.button.cancel,
        ),
        AndroidAuthMessages(
          signInHint: translations.localAuth.android.signInHint,
          signInTitle: translations.localAuth.android.signInTitle,
          cancelButton: translations.appUnlock.button.cancel,
        ),
        const WindowsAuthMessages(),
      ],
    );
    if (currentPlatform.isDesktop) {
      if (currentPlatform == Platform.macOS || currentPlatform == Platform.windows) {
        // See https://github.com/flutter/flutter/issues/122322.
        await windowManager.blur();
        await windowManager.focus();
      }
      await windowManager.setAlwaysOnTop(false);
    }
    return result;
  }

  @override
  Future<bool> isSupported() => _localAuthentication.isDeviceSupported();
}
