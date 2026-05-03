import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:open_authenticator/model/backup.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/utils/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// How a [Result] should be reported.
enum ResultReporting {
  /// Does not report the result.
  none(
    reporters: [
      NoopResultReporter(),
    ],
  ),

  /// Reports [ResultError] to the console.
  console(
    reporters: [
      ConsoleResultReporter(),
    ],
  ),

  /// Reports [ResultError] to Sentry.
  sentry(
    reporters: [
      SentryResultReporter(),
    ],
  ),

  /// Reports [ResultError] to the console and Sentry.
  consoleAndSentry(
    reporters: [
      ConsoleResultReporter(),
      SentryResultReporter(),
    ],
  )
  ;

  /// The reporters to use.
  final List<ResultReporter> _reporters;

  /// Creates a new result reporting instance.
  const ResultReporting({
    required List<ResultReporter> reporters,
  }) : _reporters = reporters;
}

/// Prints the [ex] and [stackTrace] to the console.
/// Optionally sends the exception to Sentry.
void printException(Object ex, StackTrace? stackTrace, {bool? sendToSentry}) {
  reportResult(
    ResultError(
      exception: ex,
      stackTrace: stackTrace,
    ),
    reporting: sendToSentry == false || !kSentryEnabled ? (kDebugMode ? .console : .none) : .consoleAndSentry,
  );
}

/// Reports the [result] with the given [reporting].
void reportResult<T>(
  Result<T> result, {
  ResultReporting? reporting,
}) {
  if (reporting == null && result is ResultError) {
    if (kDebugMode) {
      reporting = _sendToSentry((result as ResultError).exception) ? .consoleAndSentry : .console;
    } else {
      reporting = _sendToSentry((result as ResultError).exception) ? .sentry : .none;
    }
  }
  if (reporting != null) {
    for (ResultReporter reporter in reporting._reporters) {
      reporter.report(result);
    }
  }
}

/// Whether the given [ex] should be sent to Sentry.
bool _sendToSentry(Object? ex) =>
    kSentryEnabled &&
    switch (ex) {
      SocketException(:final osError) => !{7, 8}.contains(osError?.errorCode),
      TimeoutException() => false,
      ProviderUserAlreadyExists() => false,
      ExpiredCodeError() => false,
      EmailAlreadySentException() => false,
      InvalidVerificationCodeError() => false,
      InvalidAuthorizationCodeError() => false,
      InvalidBackupPasswordException() => false,
      _ => true,
    };

/// Reports a [Result].
abstract interface class ResultReporter {
  /// Reports the given [result].
  void report<T>(Result<T> result);
}

/// Does not report results.
class NoopResultReporter implements ResultReporter {
  /// Creates a new no-op result reporter instance.
  const NoopResultReporter();

  @override
  void report<T>(Result<T> result) {}
}

/// Reports [ResultError] to the console.
class ConsoleResultReporter implements ResultReporter {
  /// Creates a new console result reporter instance.
  const ConsoleResultReporter();

  @override
  void report<T>(Result<T> result) {
    if (result is! ResultError<T>) {
      return;
    }
    debugPrintStack(
      label: result.exception.toString(),
      stackTrace: result.stackTrace,
    );
  }
}

/// Reports [ResultError] to Sentry.
class SentryResultReporter implements ResultReporter {
  /// Creates a new Sentry result reporter instance.
  const SentryResultReporter();

  @override
  void report<T>(Result<T> result) {
    if (result is! ResultError<T> || !kSentryEnabled) {
      return;
    }
    Sentry.captureException(
      result.exception,
      stackTrace: result.stackTrace,
    );
  }
}
