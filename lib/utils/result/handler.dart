import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/utils/sentry.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/toast.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Handles [ResultSuccess] and [ResultError] with an error dialog.
const List<ResultHandler> handleSuccessAndErrorWithDialog = [
  SuccessToastResultHandler(),
  ErrorDialogResultHandler(),
  ErrorPrintResultHandler(),
];

/// Handles [ResultSuccess] and [ResultError] with an error toast.
const List<ResultHandler> handleSuccessAndErrorWithToast = [
  SuccessToastResultHandler(),
  ErrorToastResultHandler(),
  ErrorPrintResultHandler(),
];

/// Handles [ResultError] with an error dialog.
const List<ResultHandler> handleErrorOnlyWithDialog = [
  ErrorDialogResultHandler(),
  ErrorPrintResultHandler(),
];

/// Handles [ResultError] with an error toast.
const List<ResultHandler> handleErrorOnlyWithToast = [
  ErrorToastResultHandler(),
  ErrorPrintResultHandler(),
];

/// Handles the [result] with the given [resultHandlers].
void handleResult<T>(
  BuildContext context,
  Result<T> result, {
  List<ResultHandler> resultHandlers = handleSuccessAndErrorWithDialog,
  MessageBuilder<T>? buildSuccessToastMessage,
  MessageBuilder<Object?>? buildErrorToastMessage,
  MessageBuilder<Object?>? buildErrorDialogMessage,
}) {
  P createParams<P>(ResultHandler<P> handler) {
    switch (handler) {
      case SuccessToastResultHandler():
        SuccessToastResultHandlerParams<T> params = (context: context, successMessage: buildSuccessToastMessage);
        return params as P;
      case ErrorToastResultHandler():
        ErrorToastResultHandlerParams params = (context: context, errorMessage: buildErrorToastMessage);
        return params as P;
      case ErrorDialogResultHandler():
        ErrorDialogResultHandlerParams params = (context: context, errorMessage: buildErrorDialogMessage);
        return params as P;
      case ErrorPrintResultHandler():
        ErrorPrintResultHandlerParams params = (sendToSentry: null);
        return params as P;
      default:
        throw ArgumentError.value(handler);
    }
  }

  return _handleResultRaw(
    result,
    resultHandlers: resultHandlers,
    createParams: createParams,
  );
}

/// Prints the [ex] and [stackTrace] to the console.
/// Optionally sends the exception to Sentry.
void printException(
  Object ex,
  StackTrace? stackTrace, {
  bool? Function(Object?)? sendToSentry,
}) {
  P createParams<P>(ResultHandler<P> handler) {
    switch (handler) {
      case ErrorPrintResultHandler():
        ErrorPrintResultHandlerParams params = (sendToSentry: sendToSentry);
        return params as P;
      default:
        throw ArgumentError.value(handler);
    }
  }

  _handleResultRaw(
    ResultError(exception: ex, stackTrace: stackTrace),
    createParams: createParams,
  );
}

/// Handles the [result] with the given [resultHandlers].
/// Parameters are created using [createParams].
void _handleResultRaw<T>(
  Result<T> result, {
  List<ResultHandler> resultHandlers = handleSuccessAndErrorWithDialog,
  required P Function<P>(ResultHandler<P> handler) createParams,
}) {
  for (ResultHandler handler in resultHandlers) {
    if (handler.canHandle(result)) {
      handler.handle(result, createParams.call(handler));
      return;
    }
  }
}

/// A message builder.
typedef MessageBuilder<T> = String? Function(T? argument);

/// A result handler.
mixin ResultHandler<P> {
  /// Whether this handler can handle the given [result].
  bool canHandle<T>(Result<T> result);

  /// Handles the given [result] with the given [params].
  void handle<T>(Result<T> result, P params);
}

/// The parameters to pass to [SuccessToastResultHandler].
typedef SuccessToastResultHandlerParams<T> = ({BuildContext context, MessageBuilder<T>? successMessage});

/// Handles [ResultSuccess] with a success toast.
class SuccessToastResultHandler with ResultHandler<SuccessToastResultHandlerParams> {
  /// Creates a new success toast result handler instance.
  const SuccessToastResultHandler();

  @override
  bool canHandle<T>(Result<T> result) => result is ResultSuccess;

  @override
  void handle<T>(Result<T> result, SuccessToastResultHandlerParams params) {
    showSuccessToast(
      params.context,
      text: params.successMessage?.call((result as ResultSuccess).valueOrNull) ?? translations.error.noError,
    );
  }
}

/// The parameters to pass to [ErrorToastResultHandler].
typedef ErrorToastResultHandlerParams = ({BuildContext context, MessageBuilder<Object?>? errorMessage});

/// Handles [ResultError] with an error toast.
class ErrorToastResultHandler with ResultHandler<ErrorToastResultHandlerParams> {
  /// Creates a new error toast result handler instance.
  const ErrorToastResultHandler();

  @override
  bool canHandle<T>(Result<T> result) => result is ResultError;

  @override
  void handle<T>(Result<T> result, ErrorToastResultHandlerParams params) {
    ResultError error = result as ResultError;
    String? message = params.errorMessage?.call(error.exception);
    if (message == null) {
      if (error.exception is LocalizableException) {
        message = (error.exception as LocalizableException).localizedErrorMessage;
      }
      message ??= translations.error.generic.withException(exception: error.exception);
    }
    showErrorToast(
      params.context,
      text: message,
    );
  }
}

/// The parameters to pass to [ErrorDialogResultHandler].
typedef ErrorDialogResultHandlerParams = ({BuildContext context, MessageBuilder<Object?>? errorMessage});

/// Handles [ResultError] with an error dialog.
class ErrorDialogResultHandler with ResultHandler<ErrorDialogResultHandlerParams> {
  /// Creates a new error dialog result handler instance.
  const ErrorDialogResultHandler();

  @override
  bool canHandle<T>(Result<T> result) => result is ResultError;

  @override
  void handle<T>(Result<T> result, ErrorDialogResultHandlerParams params) {
    ResultError error = result as ResultError;
    String? message = params.errorMessage?.call(error.exception);
    ErrorDialog.openDialog(
      params.context,
      error: error.exception,
      stackTrace: error.stackTrace,
      message: message,
    );
  }
}

/// The parameters to pass to [ErrorPrintResultHandler].
typedef ErrorPrintResultHandlerParams = ({bool? Function(Object?)? sendToSentry});

/// Handles [ResultError] by printing it to the console and optionally sending it to Sentry.
class ErrorPrintResultHandler with ResultHandler<ErrorPrintResultHandlerParams> {
  /// Creates a new error print result handler instance.
  const ErrorPrintResultHandler();

  @override
  bool canHandle<T>(Result<T> result) => result is ResultError;

  @override
  void handle<T>(Result<T> result, ({bool? Function(Object?)? sendToSentry}) params) {
    ResultError error = result as ResultError;
    if (kDebugMode) {
      print(error.exception);
      print(error.stackTrace);
    }
    if (kSentryEnabled) {
      if (params.sendToSentry?.call(error.exception) ?? _sendToSentry(error.exception)) {
        Sentry.captureException(
          error.exception,
          stackTrace: error.stackTrace,
        );
      }
    }
  }

  /// Whether the given [ex] should be sent to Sentry.
  bool _sendToSentry(Object? ex) => switch (ex) {
    SocketException(:final osError) => !{7, 8}.contains(osError?.errorCode),
    TimeoutException() => false,
    ProviderUserAlreadyExists() => false,
    ExpiredCodeError() => false,
    InvalidVerificationCodeError() => false,
    InvalidAuthorizationCodeError() => false,
    _ => true,
  };
}
