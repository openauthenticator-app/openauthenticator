import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/connectivity.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/backend/synchronization/push/operation.dart';
import 'package:open_authenticator/model/backend/synchronization/push/result.dart';
import 'package:open_authenticator/model/backend/synchronization/status.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/result.dart';

/// The push operations errors provider.
final pushOperationsErrorsProvider = StreamProvider<List<PushOperationError>>((ref) => ref.watch(appDatabaseProvider).watchBackendPushOperationErrors());

/// The push operations queue provider.
final pushOperationsQueueProvider = AsyncNotifierProvider<PushOperationsQueue, List<PushOperation>>(PushOperationsQueue.new);

/// Allows to manage the push operations queue.
class PushOperationsQueue extends AsyncNotifier<List<PushOperation>> {
  @override
  Future<List<PushOperation>> build() async {
    AppDatabase database = ref.watch(appDatabaseProvider);
    StreamSubscription<List<PushOperation>> subscription = database.watchPendingBackendPushOperations().listen(_onDatabaseUpdate);
    ref.onDispose(subscription.cancel);

    return await database.listPendingBackendPushOperations();
  }

  /// Enqueues a push operation.
  Future<void> enqueue(
    PushOperation operation, {
    bool andRun = true,
  }) async {
    AppDatabase database = ref.read(appDatabaseProvider);
    await database.addPendingBackendPushOperation(operation);
    if (andRun) {
      ref.read(synchronizationControllerProvider.notifier).notifyLocalChange();
    }
  }

  /// Pushes the pending operations.
  Future<Result> _push({bool checkSettings = true}) async {
    if (checkSettings) {
      StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .localOnly) {
        return const ResultCancelled();
      }
    }
    List<PushOperation> operations = await future;
    List<PushOperation> compactedOperations = _compact(operations);
    AppDatabase database = ref.read(appDatabaseProvider);
    if (compactedOperations.length != operations.length) {
      await database.replacePendingBackendPushOperations(compactedOperations);
    }

    if (compactedOperations.isEmpty) {
      return const ResultSuccess();
    }

    Result<SynchronizationPushResponse> result = await ref
        .read(backendClientProvider.notifier)
        .sendHttpRequest(
          SynchronizationPushRequest(
            operations: compactedOperations,
          ),
        );
    if (result is! ResultSuccess<SynchronizationPushResponse>) {
      return result;
    }

    await database.applyPushResponse(result.value);
    return const ResultSuccess();
  }

  /// Compacts the push operations list.
  List<PushOperation> _compact(List<PushOperation> operations) {
    if (operations.isEmpty) {
      return [];
    }

    Set<String> processedTotpUuids = {};
    List<PushOperation> result = [];

    for (PushOperation operation in operations.reversed) {
      switch (operation) {
        case SetTotpsPushOperation(:final payload):
          Map<String, dynamic> newPayload = {
            for (MapEntry<String, dynamic> entry in payload.entries)
              if (processedTotpUuids.add(entry.key)) entry.key: entry.value,
          };
          if (newPayload.isNotEmpty) {
            result.add(operation.copyWith(payload: newPayload));
          }
          break;
        case DeleteTotpsPushOperation(:final payload):
          List<String> newPayload = payload.where((uuid) => processedTotpUuids.add(uuid)).toList();
          if (newPayload.isNotEmpty) {
            result.add(operation.copyWith(payload: newPayload));
          }
          break;
      }
    }

    return result.reversed.toList();
  }

  /// Triggered when the database updates.
  void _onDatabaseUpdate(List<PushOperation> operations) {
    if (ref.mounted) {
      state = AsyncData(operations);
    }
  }
}

/// The synchronization controller provider.
final synchronizationControllerProvider = NotifierProvider<SynchronizationController, SynchronizationStatus>(SynchronizationController.new);

/// Allows to control the synchronization process.
class SynchronizationController extends Notifier<SynchronizationStatus> {
  /// The synchronization periodic interval.
  static const Duration _kPeriodicInterval = Duration(minutes: 10);

  /// The synchronization coalesce delay.
  static const Duration _kCoalesceDelay = Duration(milliseconds: 300);

  /// A [Random] instance.
  final Random _random = Random();

  /// The current coalesce timer.
  Timer? _coalesceTimer;

  /// The current retry timer.
  Timer? _retryTimer;

  @override
  SynchronizationStatus build() {
    StorageType? storageType = ref.read(storageTypeSettingsEntryProvider).value;
    if (storageType == StorageType.localOnly) {
      return SynchronizationStatus();
    }

    ref.onDispose(_dispose);

    Timer periodicTimer = Timer.periodic(_kPeriodicInterval, (_) => notifyLocalChange());
    ref.onDispose(periodicTimer.cancel);

    notifyLocalChange();

    AsyncValue<bool> connectivityState = ref.watch(connectivityStateProvider);
    return SynchronizationStatus(
      phase: connectivityState.value == true ? const SynchronizationPhaseIdle() : const SynchronizationPhaseOffline(),
    );
  }

  /// Disposes the controller.
  void _dispose() {
    _coalesceTimer?.cancel();
    _retryTimer?.cancel();

    _coalesceTimer = null;
    _retryTimer = null;
  }

  /// Notifies the local change.
  void notifyLocalChange({bool checkSettings = true}) {
    if (_retryTimer != null) {
      return;
    }

    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(
      _kCoalesceDelay,
      () {
        _coalesceTimer = null;
        _run(checkSettings: checkSettings);
      },
    );
  }

  /// Forces a synchronization.
  Future<void> forceSync({bool checkSettings = true}) async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    await _run(checkSettings: checkSettings);
  }

  /// Runs the synchronization.
  Future<void> _run({bool checkSettings = true}) async {
    if (!ref.mounted) {
      return;
    }
    bool hasError = false;
    try {
      if (state.phase is SynchronizationPhaseSyncing) {
        return;
      }

      state = state.copyWith(
        phase: const SynchronizationPhaseSyncing(),
      );
      await state.waitBeforeNextOperation();
      if (ref.mounted) {
        state = state.update(
          retryAttempt: state.retryAttempt + 1,
        );
      }

      bool isNotOffline = await ref.read(connectivityStateProvider.future);
      if (isNotOffline) {
        void onFinish({bool errorOccurred = false}) {
          if (ref.mounted) {
            state = state.update(
              phase: const SynchronizationPhaseUpToDate(),
              retryAttempt: errorOccurred ? state.retryAttempt : 0,
            );
          }
        }

        Result pushResult = await ref.read(pushOperationsQueueProvider.notifier)._push(checkSettings: checkSettings);
        if (pushResult is! ResultSuccess) {
          if (pushResult is ResultCancelled) {
            onFinish(errorOccurred: false);
          } else {
            hasError = true;
            (Object, StackTrace) error = pushResult is ResultError ? (pushResult.exception, pushResult.stackTrace) : (Exception('An error occurred while pushing.'), StackTrace.current);
            Error.throwWithStackTrace(error.$1, error.$2);
          }
        } else {
          Result pullResult = await _pull(checkSettings: checkSettings);
          if (pullResult is! ResultSuccess) {
            if (pullResult is ResultCancelled) {
              onFinish(errorOccurred: false);
            } else {
              hasError = true;
              (Object, StackTrace) error = pullResult is ResultError ? (pullResult.exception, pullResult.stackTrace) : (Exception('An error occurred while pulling.'), StackTrace.current);
              Error.throwWithStackTrace(error.$1, error.$2);
            }
          }

          onFinish(errorOccurred: false);
        }
      } else {
        if (ref.mounted) {
          state = state.update(phase: const SynchronizationPhaseOffline());
        }
      }
    } catch (ex, stackTrace) {
      hasError = true;
      if (ref.mounted) {
        state = state.update(
          phase: SynchronizationPhaseError(
            exception: ex,
            stackTrace: stackTrace,
          ),
        );
      }
    }

    if (hasError) {
      _scheduleRetry();
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  /// Schedules a retry.
  void _scheduleRetry() {
    int jitterMs = _random.nextInt(250);

    _retryTimer?.cancel();
    _retryTimer = Timer(
      Duration(
        seconds: state.calculateRetrySeconds(),
        milliseconds: jitterMs,
      ),
      () {
        _retryTimer = null;
        _run();
      },
    );
  }

  /// Pulls changes from the backend.
  Future<Result> _pull({bool checkSettings = true}) async {
    if (checkSettings) {
      StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == StorageType.localOnly) {
        return const ResultCancelled();
      }
    }
    List<Totp> totps = await ref.read(totpRepositoryProvider.future);
    Result<SynchronizationPullResponse> result = await ref
        .read(backendClientProvider.notifier)
        .sendHttpRequest(
          SynchronizationPullRequest(
            timestamps: {
              for (Totp totp in totps) totp.uuid: totp.updatedAt,
            },
          ),
        );
    if (result is! ResultSuccess<SynchronizationPullResponse>) {
      return result;
    }

    TotpRepository repository = ref.read(totpRepositoryProvider.notifier);
    await repository.addTotps(
      result.value.inserts,
      fromNetwork: true,
    );
    await repository.updateTotps(
      result.value.updates,
      fromNetwork: true,
    );
    await repository.deleteTotps(
      result.value.deletes,
      fromNetwork: true,
    );
    return const ResultSuccess();
  }
}
