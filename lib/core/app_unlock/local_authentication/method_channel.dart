import 'package:flutter/services.dart';
import 'package:open_authenticator/core/app_unlock/local_authentication/local_authentication.dart';
import 'package:open_authenticator/core/app_unlock/reason.dart';

/// A LocalAuthentication implementation that uses method channel.
class LocalAuthenticationMethodChannel extends LocalAuthentication {
  /// The method channel.
  final MethodChannel _methodChannel = const MethodChannel('app.openauthenticator.localauth');

  @override
  Future<bool> authenticate(UnlockReason reason) async =>
      await _methodChannel.invokeMethod<bool>(
        'localAuth.authenticate',
        {
          'reason': reason.name,
        },
      ) ==
      true;

  @override
  Future<bool> isSupported() async => (await _methodChannel.invokeMethod<bool>('localAuth.isDeviceSupported')) == true;
}
