import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:xdg_desktop_portal/xdg_desktop_portal.dart';

/// The connectivity state provider.
final connectivityStateProvider = AsyncNotifierProvider<ConnectivityStateNotifier, ConnectivityState>(ConnectivityStateNotifier.new);

/// Allows to manage the connectivity state.
class ConnectivityStateNotifier extends AsyncNotifier<ConnectivityState> {
  @override
  Future<ConnectivityState> build() async {
    try {
      if (currentPlatform == .linux) {
        XdgDesktopPortalClient xdgDesktopPortalClient = XdgDesktopPortalClient();
        ref.onDispose(xdgDesktopPortalClient.close);
        Completer<ConnectivityState> initialState = Completer();

        void onConnectivityChanged(XdgNetworkStatus status) {
          ConnectivityState connectivityState = status.available ? .available : .unavailable;
          if (!initialState.isCompleted) {
            initialState.complete(connectivityState);
          }
          if (ref.mounted) {
            state = AsyncData(connectivityState);
          }
        }

        void onConnectivityError(Object error, StackTrace stackTrace) {
          printException(error, stackTrace);
          if (!initialState.isCompleted) {
            initialState.completeError(error, stackTrace);
          }
          if (ref.mounted) {
            state = const AsyncData(.unknown);
          }
        }

        StreamSubscription<XdgNetworkStatus> subscription = xdgDesktopPortalClient.networkMonitor.status.listen(
          onConnectivityChanged,
          onError: onConnectivityError,
        );
        ref.onDispose(subscription.cancel);

        return await initialState.future;
      } else {
        Connectivity connectivity = Connectivity();

        void onConnectivityChanged(List<ConnectivityResult> result) {
          if (ref.mounted) {
            state = AsyncData(result.associatedConnectivityState);
          }
        }

        void onConnectivityError(Object error, StackTrace stackTrace) {
          printException(error, stackTrace);
          if (ref.mounted) {
            state = const AsyncData(.unknown);
          }
        }

        StreamSubscription<List<ConnectivityResult>>? subscription = connectivity.onConnectivityChanged.listen(
          onConnectivityChanged,
          onError: onConnectivityError,
        );
        ref.onDispose(subscription.cancel);

        List<ConnectivityResult> result = await connectivity.checkConnectivity();
        return result.associatedConnectivityState;
      }
    } catch (ex, stackTrace) {
      printException(ex, stackTrace);
      return .unknown;
    }
  }
}

/// The connectivity state.
enum ConnectivityState {
  /// The connectivity is available.
  available,

  /// The connectivity is unavailable.
  unavailable,

  /// We couldn't determine the connectivity state.
  unknown
  ;

  /// Returns whether we can send HTTP requests.
  bool get canSendRequests => this == .available || this == .unknown;
}

/// Extension on [List<ConnectivityResult>] to check if the connectivity is available or not.
extension _AreAcceptable on List<ConnectivityResult> {
  /// Returns the associated connectivity state.
  ConnectivityState get associatedConnectivityState => firstOrNull == .none ? .unavailable : .available;
}
