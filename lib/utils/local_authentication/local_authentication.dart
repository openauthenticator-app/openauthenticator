import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/utils/local_authentication/default.dart';
import 'package:open_authenticator/utils/local_authentication/method_channel.dart';
import 'package:open_authenticator/utils/local_authentication/stub.dart';
import 'package:open_authenticator/utils/platform.dart';

/// Allows to either use LocalAuthentication's Firebase Auth implementation or fallback to the method channel if needed.
abstract class LocalAuthentication {
  /// The current [LocalAuthentication] instance.
  static LocalAuthentication? _instance;

  /// Returns the [FirebaseAuth] instance corresponding to the current platform.
  static LocalAuthentication get instance {
    if (_instance == null) {
      switch (currentPlatform) {
        case Platform.linux:
          _instance = LocalAuthenticationMethodChannel();
          break;
        case Platform.android:
        case Platform.iOS:
        case Platform.macOS:
        case Platform.windows:
          _instance = LocalAuthenticationDefault();
          break;
        case Platform.web:
          _instance = LocalAuthenticationStub();
          break;
      }
    }
    return _instance!;
  }

  /// Returns whether this unlock method is supported;
  Future<bool> isSupported();

  /// Authenticates the user.
  Future<bool> authenticate(UnlockReason reason);
}
