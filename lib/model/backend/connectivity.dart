import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The connectivity state provider.
final connectivityStateProvider = AsyncNotifierProvider<ConnectivityStateNotifier, bool>(ConnectivityStateNotifier.new);

/// Allows to manage the connectivity state.
class ConnectivityStateNotifier extends AsyncNotifier<bool> with WidgetsBindingObserver {
  /// The [Connectivity] instance.
  final Connectivity _connectivity = Connectivity();

  @override
  Future<bool> build() async {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));

    StreamSubscription<List<ConnectivityResult>>? subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    ref.onDispose(subscription.cancel);

    List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    return result.areAcceptable();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    _onConnectivityChanged(state == .resumed ? (await _connectivity.checkConnectivity()) : [.none], state: state);
  }

  /// Triggered when the connectivity state has changed.
  void _onConnectivityChanged(List<ConnectivityResult> result, {AppLifecycleState? state}) {
    if (ref.mounted) {
      this.state = AsyncData(result.areAcceptable(state: state));
    }
  }
}

/// Extension on [List<ConnectivityResult>] to check if the connectivity state is acceptable.
extension _AreAcceptable on List<ConnectivityResult> {
  /// Checks if the connectivity state is acceptable.
  bool areAcceptable({AppLifecycleState? state}) => (state ?? WidgetsBinding.instance.lifecycleState) == .resumed && firstOrNull != .none;
}
