import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
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
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result/result.dart';

/// The push operations errors provider.
final pushOperationsErrorsProvider = StreamProvider<List<PushOperationError>>((ref) => ref.watch(appDatabaseProvider).watchBackendPushOperationErrors());

/// The push operations queue provider.
final pushOperationsQueueProvider = AsyncNotifierProvider<PushOperationsQueue, List<PushOperation>>(PushOperationsQueue.new);

/// Allows to manage the push operations queue.
class PushOperationsQueue extends AsyncNotifier<List<PushOperation>> {
  /// The push operation timeout.
  static const Duration _kPushOperationTimeout = Duration(seconds: 20);

  @override
  Future<List<PushOperation>> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final StreamSubscription<List<PushOperation>> subscription = database.watchPendingBackendPushOperations().listen(_onDatabaseUpdate);
    ref.onDispose(subscription.cancel);

    return await database.listPendingBackendPushOperations();
  }

  /// Pushes the pending operations.
  Future<Result<List<PushOperationResult>>> _push({bool checkSettings = true}) async {
    if (checkSettings) {
      final StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == .localOnly) {
        return const ResultCancelled();
      }
    }
    final AppDatabase database = ref.read(appDatabaseProvider);
    final List<PushOperation> compactedOperations = await database.compactPendingOperations();
    if (compactedOperations.isEmpty) {
      return const ResultSuccess(value: []);
    }

    final Result<SynchronizationPushResponse> result = await ref
        .read(backendClientProvider.notifier)
        .sendHttpRequest(
          SynchronizationPushRequest(
            operations: compactedOperations.reversed.toList(),
          ),
          timeout: _kPushOperationTimeout,
        );
    if (result is! ResultSuccess<SynchronizationPushResponse>) {
      return result.to((_) => null);
    }

    await database.applyPushResponse(result.value);
    return ResultSuccess(value: result.value.result);
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
class SynchronizationController extends Notifier<SynchronizationStatus> with WidgetsBindingObserver {
  /// The synchronization pull timeout.
  static const Duration _kPullTimeout = Duration(seconds: 20);

  /// The synchronization periodic interval.
  static const Duration _kPeriodicInterval = Duration(minutes: 30);

  /// The minimum delay between two automatic foreground synchronizations.
  static const Duration _kForegroundSyncThrottle = Duration(minutes: 10);

  /// The synchronization coalesce delay.
  static const Duration _kCoalesceDelay = Duration(milliseconds: 300);

  /// A [Random] instance.
  final Random _random = Random();

  /// The current coalesce timer.
  Timer? _coalesceTimer;

  bool _syncRequestedWhileRunning = false;

  /// The current retry timer.
  Timer? _retryTimer;

  /// The last time a synchronization completed successfully.
  DateTime? _lastSuccessfulSync;

  @override
  SynchronizationStatus build() {
    final StorageType? storageType = ref.watch(storageTypeSettingsEntryProvider).value;
    if (storageType == .localOnly) {
      return SynchronizationStatus();
    }

    final Timer periodicTimer = Timer.periodic(_kPeriodicInterval, (_) => notifyLocalChange());
    ref.onDispose(periodicTimer.cancel);

    if (currentPlatform.isMobile) {
      WidgetsBinding.instance.addObserver(this);
    }

    notifyLocalChange();
    ref.onDispose(_dispose);

    ref.listen(connectivityStateProvider, _onConnectivityChanged);
    return SynchronizationStatus(
      phase: const SynchronizationPhaseIdle(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == .resumed) {
      forceSync(skipIfRecentlySynced: true);
    }
  }

  /// Triggered when the connectivity state has changed.
  void _onConnectivityChanged(AsyncValue<ConnectivityState>? previous, AsyncValue<ConnectivityState> next) {
    final bool canSendRequests = next.value?.canSendRequests == true;
    if (ref.mounted && state.phase is! SynchronizationPhaseSyncing) {
      state = state.update(
        phase: canSendRequests ? const SynchronizationPhaseIdle() : const SynchronizationPhaseOffline(),
      );
    }
    if (canSendRequests && previous?.value?.canSendRequests != true) {
      // We're back online, so let's push the pending operations.
      notifyLocalChange();
    }
  }

  /// Disposes the controller.
  void _dispose() {
    _coalesceTimer?.cancel();
    _retryTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    _coalesceTimer = null;
    _retryTimer = null;
  }

  /// Notifies the local change.
  void notifyLocalChange({bool checkSettings = true}) {
    _retryTimer?.cancel();
    _retryTimer = null;
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
  Future<void> forceSync({
    bool checkSettings = true,
    bool skipIfRecentlySynced = false,
  }) async {
    if (skipIfRecentlySynced && await _shouldSkipRecentAutomaticSync()) {
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    await _run(checkSettings: checkSettings);
  }

  /// Returns whether an automatic foreground synchronization can be skipped.
  Future<bool> _shouldSkipRecentAutomaticSync() async {
    if (_lastSuccessfulSync == null || DateTime.now().difference(_lastSuccessfulSync!) >= _kForegroundSyncThrottle) {
      return false;
    }

    final List<PushOperation> operations = await ref.read(pushOperationsQueueProvider.future);
    return operations.isEmpty;
  }

  /// Runs the synchronization.
  Future<void> _run({bool checkSettings = true}) async {
    if (!ref.mounted) {
      return;
    }
    if (state.phase is SynchronizationPhaseSyncing) {
      _syncRequestedWhileRunning = true;
      return;
    }
    state = state.copyWith(
      phase: const SynchronizationPhaseSyncing(),
    );
    try {
      await state.waitBeforeNextOperation();
      if (!ref.mounted) {
        return;
      }
      state = state.update(
        retryAttempt: state.retryAttempt + 1,
      );

      final bool canSendRequests = (await ref.read(connectivityStateProvider.future)).canSendRequests;
      if (!canSendRequests) {
        if (ref.mounted) {
          state = state.update(phase: const SynchronizationPhaseOffline());
        }
        return;
      }

      final Result<List<PushOperationResult>> pushResult = await ref.read(pushOperationsQueueProvider.notifier)._push(checkSettings: checkSettings);
      _throwIfError(pushResult);
      if (pushResult is! ResultSuccess<List<PushOperationResult>>) {
        if (ref.mounted) {
          state = state.update(phase: const SynchronizationPhaseIdle());
        }
        return;
      }
      final Result pull = await _pull(checkSettings: checkSettings);
      _throwIfError(pull);
      if (pull is! ResultSuccess) {
        if (ref.mounted) {
          state = state.update(phase: const SynchronizationPhaseIdle());
        }
        return;
      }
      for (final PushOperationResult result in pushResult.value) {
        final PushOperationErrorKind? error = result.errorKind;
        if (error == PushOperationErrorKind.maxOperationsCountExceeded) {
          _syncRequestedWhileRunning = true;
        } else if (error != null && !error.isPermanent) {
          throw StateError(error.localizedMessage);
        }
      }

      _lastSuccessfulSync = DateTime.now();
      _retryTimer?.cancel();
      _retryTimer = null;
      if (ref.mounted) {
        state = state.update(
          phase: const SynchronizationPhaseUpToDate(),
          retryAttempt: 0,
        );
      }
    } catch (ex, stackTrace) {
      if (ref.mounted) {
        state = state.update(
          phase: SynchronizationPhaseError(
            exception: ex,
            stackTrace: stackTrace,
          ),
        );
      }
      if (ref.mounted) {
        _scheduleRetry();
      }
    } finally {
      if (_syncRequestedWhileRunning && ref.mounted) {
        _syncRequestedWhileRunning = false;
        notifyLocalChange(checkSettings: checkSettings);
      }
    }
  }

  /// Throws the exception of the [result] if it's an error.
  void _throwIfError(Result result) {
    if (result is ResultError) {
      Error.throwWithStackTrace(result.exception, result.stackTrace);
    }
  }

  /// Schedules a retry.
  void _scheduleRetry() {
    final int jitterMs = _random.nextInt(250);

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
      final StorageType storageType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (storageType == StorageType.localOnly) {
        return const ResultCancelled();
      }
    }

    final List<Totp> totps = await ref.read(totpRepositoryProvider.future);
    final DeletedTotpMap deletedTotps = await ref.read(appDatabaseProvider).getDeletedTotps();
    final Result<SynchronizationPullResponse> result = await ref
        .read(backendClientProvider.notifier)
        .sendHttpRequest(
          SynchronizationPullRequest(
            active: {
              for (final Totp totp in totps) totp.uuid: totp.updatedAt,
            },
            deleted: deletedTotps,
          ),
          timeout: _kPullTimeout,
        );

    if (result is! ResultSuccess<SynchronizationPullResponse>) {
      return result;
    }

    final TotpRepository repository = ref.read(totpRepositoryProvider.notifier);
    final Result addResult = await repository.addTotps(
      result.value.inserts,
      fromNetwork: true,
    );
    if (addResult is! ResultSuccess) {
      return addResult;
    }
    final Result updateResult = await repository.updateTotps(
      result.value.updates,
      fromNetwork: true,
    );
    if (updateResult is! ResultSuccess) {
      return updateResult;
    }
    final Result deleteResult = await repository.deleteTotps(
      result.value.deletes,
      fromNetwork: true,
    );
    if (deleteResult is! ResultSuccess) {
      return deleteResult;
    }
    return const ResultSuccess();
  }
}
