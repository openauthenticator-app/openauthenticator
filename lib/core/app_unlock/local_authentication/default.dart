import 'package:local_auth/local_auth.dart' as local_auth;
// ignore: depend_on_referenced_packages
import 'package:local_auth_android/local_auth_android.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_darwin/local_auth_darwin.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_darwin/types/auth_messages_macos.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:open_authenticator/core/app_unlock/local_authentication/local_authentication.dart';
import 'package:open_authenticator/core/app_unlock/reason.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/window.dart';
import 'package:window_manager/window_manager.dart';

/// Uses Flutter's LocalAuthentication implementation.
class LocalAuthenticationDefault extends LocalAuthentication {
  /// The [local_auth.LocalAuthentication] instance.
  final local_auth.LocalAuthentication _localAuthentication;

  /// Whether a native authentication prompt is already open.
  bool _authenticating = false;

  /// Creates a new default local authentication instance.
  LocalAuthenticationDefault() : _localAuthentication = local_auth.LocalAuthentication();

  @override
  Future<bool> authenticate(UnlockReason reason) async {
    final Window? window = currentWindow;
    final bool wasAlwaysOnTop = window?.isAlwaysOnTop ?? false;
    if (_authenticating) {
      return false;
    }
    _authenticating = true;
    try {
      window
        ?..focus()
        ..isAlwaysOnTop = true;
      return await _localAuthentication.authenticate(
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
    } finally {
      _authenticating = false;
      if (window != null) {
        window.isAlwaysOnTop = wasAlwaysOnTop;
        if (currentPlatform == Platform.macOS || currentPlatform == Platform.windows) {
          // See https://github.com/flutter/flutter/issues/122322.
          window
            ..blur()
            ..focus();
        }
      }
    }
  }

  @override
  Future<bool> isSupported() => _localAuthentication.isDeviceSupported();
}
