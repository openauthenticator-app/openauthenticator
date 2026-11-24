import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
  );

  /// The reporters to use.
  final List<ResultReporter> _reporters;

  /// Creates a new result reporting instance.
  const ResultReporting({
    required this._reporters,
  });
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
  final ResultReporting? actualReporting = switch (result) {
    _ when reporting != null => reporting,
    ResultError(:final exception) when kDebugMode => _sendToSentry(exception) ? .consoleAndSentry : .console,
    ResultError(:final exception) => _sendToSentry(exception) ? .sentry : .none,
    _ => null,
  };
  if (actualReporting != null) {
    for (final ResultReporter reporter in actualReporting._reporters) {
      reporter.report(result);
    }
  }
}

/// Whether the given [ex] should be sent to Sentry.
bool _sendToSentry(Object? ex) => kSentryEnabled && isReportableException(ex);

/// Whether the given [ex] is worth reporting.
/// Network failures and busy clipboards depend on the user environment (connection, proxies, other apps), so they cannot be fixed by the app.
/// This is also used to filter the errors that are automatically caught by Sentry.
bool isReportableException(Object? ex) => switch (ex) {
  UserError(:final reportToSentry) => reportToSentry,
  SocketException() || HandshakeException() || http.ClientException() || TimeoutException() => false,
  // Another app may hold the Windows clipboard, including when a text field pastes text.
  PlatformException(code: 'Clipboard error') => false,
  // Cancelling a platform event stream that is already closed (eg. by a plugin restarting its stream) has no effect.
  PlatformException(code: 'error', message: 'No active stream to cancel') => false,
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

/// An user error, that may not be reported to Sentry.
mixin UserError {
  /// Whether the error should be reported to Sentry.
  bool get reportToSentry => false;
}
