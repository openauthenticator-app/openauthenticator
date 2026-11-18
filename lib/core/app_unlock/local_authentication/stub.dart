import 'package:open_authenticator/core/app_unlock/local_authentication/local_authentication.dart';
import 'package:open_authenticator/core/app_unlock/reason.dart';

/// A LocalAuthentication implementation that does nothing.
class LocalAuthenticationStub extends LocalAuthentication {
  @override
  Future<bool> isSupported() => Future.value(false);

  @override
  Future<bool> authenticate(UnlockReason reason) => Future.value(false);
}
