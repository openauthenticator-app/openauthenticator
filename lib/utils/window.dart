import 'package:open_authenticator/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

/// Returns the current native window, if running on desktop.
Window? get currentWindow => currentPlatform.isDesktop ? WindowManager.instance.getCurrent() : null;
