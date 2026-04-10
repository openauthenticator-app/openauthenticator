import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The connectivity state provider.
final connectivityStateProvider = AsyncNotifierProvider<ConnectivityStateNotifier, bool>(ConnectivityStateNotifier.new);

/// Allows to manage the connectivity state.
class ConnectivityStateNotifier extends AsyncNotifier<bool> {
  /// The [Connectivity] instance.
  final Connectivity _connectivity = Connectivity();

  @override
  Future<bool> build() async {
    StreamSubscription<List<ConnectivityResult>>? subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    ref.onDispose(subscription.cancel);

    List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    return result.firstOrNull != ConnectivityResult.none;
  }

  /// Triggered when the connectivity state has changed.
  void _onConnectivityChanged(List<ConnectivityResult> result) {
    if (ref.mounted) {
      state = AsyncData(result.firstOrNull != ConnectivityResult.none);
    }
  }
}
