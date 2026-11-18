import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

Window? _primaryWindow;

/// The app window used for its title bar and authentication dialogs.
Window? get currentWindow {
  if (currentPlatform.isDesktop && currentPlatform != Platform.windows) {
    _primaryWindow ??= WindowManager.instance.getCurrent();
  }
  return _primaryWindow;
}

/// Resolves the runner's window once, including when Windows starts unfocused.
Future<Window?> initializePrimaryWindow() async {
  if (currentPlatform == Platform.windows) {
    const channel = MethodChannel('app.openauthenticator.window');
    final int handle = (await channel.invokeMethod<int>('getHandle'))!;
    return _primaryWindow = Window.createWithNativeWindow(Pointer<Void>.fromAddress(handle));
  }
  return currentWindow;
}
