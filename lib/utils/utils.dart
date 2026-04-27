import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hashlib_codecs/hashlib_codecs.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Whether Sentry is enabled.
bool kSentryEnabled = !kDebugMode && App.sentryDsn.isNotEmpty;

/// Returns whether an exception should be sent to Sentry.
bool shouldSendErrorToSentry(Object? ex) => switch (ex) {
  SocketException(:final osError) => osError?.errorCode != 7,
  TimeoutException() => false,
  ProviderUserAlreadyExists() => false,
  ExpiredCodeError() => false,
  InvalidVerificationCodeError() => false,
  InvalidAuthorizationCodeError() => false,
  _ => true,
};

/// Contains some useful iterable methods.
extension IterableUtils<T> on Iterable<T> {
  /// Returns the first element satisfying [test], or `null` if there are none.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// Returns whether a given [string] is a valid base 32 string.
bool isValidBase32(String string) {
  try {
    fromBase32(string);
    return true;
  } catch (_) {}
  return false;
}

/// Handles an exception.
void handleException(Object? ex, StackTrace? stackTrace, {bool? sendToSentry}) {
  if (kDebugMode) {
    print(ex);
    print(stackTrace);
  }
  if (sendToSentry ?? kSentryEnabled) {
    Sentry.captureException(
      ex,
      stackTrace: stackTrace,
    );
  }
}

/// Returns whether the given type [S] is a subtype of type [T].
bool isSubtype<S, T>() => <S>[] is List<T>;

/// A simple transparent image. Represented as a Uint8List, which was originally extracted from the Flutter codebase.
Uint8List kTransparentImage = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// Contains some useful color methods.
extension ColorUtils on Color {
  /// Highlights the color.
  Color highlight({double amount = 0.1}) => computeLuminance() > 0.4 ? darken(amount: amount) : lighten(amount: amount);

  /// Lightens the color.
  Color lighten({double amount = 0.1}) {
    assert(amount >= 0 && amount <= 1);

    HSLColor hsl = HSLColor.fromColor(this);
    HSLColor hslDark = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }

  /// Darkens the color.
  Color darken({double amount = 0.1}) {
    assert(amount >= 0 && amount <= 1);

    HSLColor hsl = HSLColor.fromColor(this);
    HSLColor hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }
}
