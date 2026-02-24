import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Represents the synchronization status.
class SynchronizationStatus with EquatableMixin {
  /// The maximum backoff duration.
  static const Duration _kMaxBackoff = Duration(minutes: 10);

  /// The current synchronization phase.
  final SynchronizationPhase phase;

  /// The current synchronization timestamp.
  final DateTime timestamp;

  /// The current retry attempt.
  final int retryAttempt;

  /// Creates a new synchronization status instance.
  SynchronizationStatus({
    this.phase = const SynchronizationPhaseIdle(),
    DateTime? timestamp,
    this.retryAttempt = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [
    phase,
    timestamp,
    retryAttempt,
  ];

  /// Updates the synchronization status.
  SynchronizationStatus update({
    DateTime? timestamp,
    SynchronizationPhase? phase,
    int? retryAttempt,
  }) => copyWith(
    phase: phase,
    retryAttempt: retryAttempt,
    timestamp: DateTime.now(),
  );

  /// Creates a copy of the synchronization status.
  SynchronizationStatus copyWith({
    SynchronizationPhase? phase,
    DateTime? timestamp,
    int? retryAttempt,
  }) => SynchronizationStatus(
    phase: phase ?? this.phase,
    timestamp: timestamp ?? this.timestamp,
    retryAttempt: retryAttempt ?? this.retryAttempt,
  );

  /// The next possible operation time.
  DateTime get nextPossibleOperationTime => timestamp.add(phase._threshold);

  /// Waits before the next operation.
  Future<void> waitBeforeNextOperation() {
    DateTime now = DateTime.now();
    if (now.isAfter(nextPossibleOperationTime)) {
      return Future.value();
    }
    return Future.delayed(nextPossibleOperationTime.difference(now));
  }

  /// Calculates the retry seconds.
  int calculateRetrySeconds() {
    int retryAttempt = math.min(this.retryAttempt <= 0 ? 1 : this.retryAttempt, 10);
    int baseSeconds = math.pow(2, retryAttempt).toInt();
    int capSeconds = _kMaxBackoff.inSeconds;
    int seconds = math.min(baseSeconds, capSeconds);
    return seconds;
  }
}

/// Represents the current synchronization phase.
sealed class SynchronizationPhase {
  /// Creates a new synchronization phase instance.
  const SynchronizationPhase();

  /// The threshold duration.
  Duration get _threshold => const Duration(seconds: 5);
}

/// Represents the idle synchronization phase.
class SynchronizationPhaseIdle extends SynchronizationPhase {
  /// Creates a new idle synchronization phase instance.
  const SynchronizationPhaseIdle();

  @override
  Duration get _threshold => Duration.zero;
}

/// Represents the offline synchronization phase.
class SynchronizationPhaseOffline extends SynchronizationPhase {
  /// Creates a new offline synchronization phase instance.
  const SynchronizationPhaseOffline();

  @override
  Duration get _threshold => Duration.zero;
}

/// Represents the syncing synchronization phase.
class SynchronizationPhaseSyncing extends SynchronizationPhase {
  /// Creates a new syncing synchronization phase instance.
  const SynchronizationPhaseSyncing();
}

/// Represents the up to date synchronization phase.
class SynchronizationPhaseUpToDate extends SynchronizationPhase {
  /// Creates a new up to date synchronization phase instance.
  const SynchronizationPhaseUpToDate();
}

/// Represents an error synchronization phase.
class SynchronizationPhaseError extends SynchronizationPhase {
  /// The exception instance.
  final Object? exception;

  /// The current stacktrace.
  final StackTrace stackTrace;

  /// Creates a new error synchronization phase instance.
  SynchronizationPhaseError({
    this.exception,
    StackTrace? stackTrace,
  }) : stackTrace = stackTrace ?? StackTrace.current;
}
