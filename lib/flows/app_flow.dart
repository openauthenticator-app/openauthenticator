import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Base class for user flows.
abstract class AppFlow {
  /// The Riverpod ref.
  final Ref ref;

  /// Creates a new flow instance.
  const AppFlow(this.ref);

  /// Keeps the flow provider alive while [action] is running.
  Future<T> keepAliveWhile<T>(Future<T> Function() action) async {
    KeepAliveLink keepAliveLink = ref.keepAlive();
    try {
      return await action();
    } finally {
      keepAliveLink.close();
    }
  }
}
