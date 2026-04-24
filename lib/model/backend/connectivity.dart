import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:xdg_desktop_portal/xdg_desktop_portal.dart';

/// The connectivity state provider.
final connectivityStateProvider = AsyncNotifierProvider<ConnectivityStateNotifier, bool>(ConnectivityStateNotifier.new);

/// Allows to manage the connectivity state.
class ConnectivityStateNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    if (currentPlatform == .linux) {
      XdgDesktopPortalClient xdgDesktopPortalClient = XdgDesktopPortalClient();
      ref.onDispose(() => unawaited(xdgDesktopPortalClient.close()));
      Completer<bool> initialState = Completer<bool>();

      void onConnectivityChanged(XdgNetworkStatus status) {
        bool isAvailable = status.available;
        if (!initialState.isCompleted) {
          initialState.complete(isAvailable);
        }
        if (ref.mounted) {
          state = AsyncData(isAvailable);
        }
      }

      void onConnectivityError(Object error, StackTrace stackTrace) {
        if (!initialState.isCompleted) {
          initialState.completeError(error, stackTrace);
        }
        if (ref.mounted) {
          state = AsyncError(error, stackTrace);
        }
      }

      StreamSubscription<XdgNetworkStatus> subscription = xdgDesktopPortalClient.networkMonitor.status.listen(
        onConnectivityChanged,
        onError: onConnectivityError,
      );
      ref.onDispose(() => unawaited(subscription.cancel()));

      return initialState.future;
    } else {
      Connectivity connectivity = Connectivity();

      void onConnectivityChanged(List<ConnectivityResult> result) {
        if (ref.mounted) {
          state = AsyncData(result.areAcceptable);
        }
      }

      void onConnectivityError(Object error, StackTrace stackTrace) {
        if (ref.mounted) {
          state = AsyncError(error, stackTrace);
        }
      }

      StreamSubscription<List<ConnectivityResult>>? subscription = connectivity.onConnectivityChanged.listen(
        onConnectivityChanged,
        onError: onConnectivityError,
      );
      ref.onDispose(() => unawaited(subscription.cancel()));

      List<ConnectivityResult> result = await connectivity.checkConnectivity();
      return result.areAcceptable;
    }
  }
}

/// Extension on [List<ConnectivityResult>] to check if the connectivity state is acceptable.
extension _AreAcceptable on List<ConnectivityResult> {
  /// Checks if the connectivity state is acceptable.
  bool get areAcceptable => firstOrNull != .none;
}
