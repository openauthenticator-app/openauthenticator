import 'package:flutter/services.dart';

/// Launches a native web authentication session.
class NativeWebAuth {
  /// The method channel used to communicate with the native platform.
  static const MethodChannel _methodChannel = MethodChannel('app.openauthenticator.webauth');

  /// Launches the native platform web authentication UI.
  /// Redirect callbacks are forwarded by native code to `app_links`.
  static Future<void> launch({
    required Uri url,
    required String callbackUrlScheme,
  }) => _methodChannel.invokeMethod<void>(
    'authenticate',
    {
      'url': url.toString(),
      'callbackUrlScheme': callbackUrlScheme,
    },
  );
}
