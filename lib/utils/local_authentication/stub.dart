import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/utils/local_authentication/local_authentication.dart';

/// A LocalAuthentication implementation that does nothing.
class LocalAuthenticationStub extends LocalAuthentication {
  @override
  Future<bool> isSupported() => Future.value(false);

  @override
  Future<bool> authenticate(UnlockReason reason) => Future.value(false);
}
