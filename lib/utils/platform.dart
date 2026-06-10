import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Returns the current platform.
Platform currentPlatform = () {
  if (kIsWeb) {
    return Platform.web;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return Platform.android;
    case TargetPlatform.iOS:
      return Platform.iOS;
    case TargetPlatform.windows:
      return Platform.windows;
    case TargetPlatform.macOS:
      return Platform.macOS;
    case TargetPlatform.linux:
      return Platform.linux;
    default:
      return Platform.web;
  }
}();

/// Allows to get some info about the current platform.
enum Platform {
  /// The Android platform.
  android(isMobile: true),

  /// The iOS platform.
  iOS(isMobile: true),

  /// The Windows platform.
  windows(isDesktop: true),

  /// The macOS platform.
  macOS(isDesktop: true),

  /// The Linux platform.
  linux(isDesktop: true),

  /// The Web platform.
  web;

  /// Whether this is a mobile platform.
  final bool isMobile;

  /// Whether this is a desktop platform.
  final bool isDesktop;

  /// Creates a new platform instance.
  const Platform({
    this.isMobile = false,
    this.isDesktop = false,
  });

  /// Generates a new app client ID.
  String generateAppClientId() => '${name.toLowerCase()}-${const Uuid().v4()}';
}
