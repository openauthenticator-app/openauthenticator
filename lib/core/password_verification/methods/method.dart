import 'dart:async';

import 'package:flutter/foundation.dart';

/// Allows to check if a given master password is valid.
mixin PasswordVerificationMethod {
  /// Whether this method is enabled.
  bool get enabled;

  /// Whether this method is 100% sure.
  bool get isSure => true;

  /// Verifies if the [password] is valid.
  @mustCallSuper
  Future<bool> verify(String password) => Future.value(enabled);
}
