import 'package:flutter/material.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/toast.dart';

/// Used all around the project to either return a success, a failure or a cancellation.
sealed class Result<T> {
  /// Creates a new result instance.
  const Result();

  /// Converts this result to another.
  Result<U> to<U>(U? Function(T?) convert);
}

/// When this is a success.
class ResultSuccess<T> extends Result<T> {
  /// The return value.
  final T? _value;

  /// Creates a new result success instance.
  const ResultSuccess({
    T? value,
  }) : _value = value;

  /// Returns the raw [_value].
  T? get valueOrNull => _value;

  /// Returns the [_value], ensuring it's not null.
  T get value => _value!;

  @override
  ResultSuccess<U> to<U>(U? Function(T?) convert) => ResultSuccess(value: convert(valueOrNull));
}

/// When an error occurred.
class ResultError<T> extends Result<T> {
  /// The exception instance.
  final Object exception;

  /// The current stacktrace.
  final StackTrace stackTrace;

  /// Creates a new result error instance.
  ResultError({
    required this.exception,
    StackTrace? stackTrace,
  }) : stackTrace = stackTrace ?? StackTrace.current {
    handleException(exception, stackTrace);
  }

  /// Creates a new result error instance from another [result].
  ResultError.fromAnother(ResultError result)
    : this(
        exception: result.exception,
        stackTrace: result.stackTrace,
      );

  @override
  ResultError<U> to<U>(_) => ResultError<U>.fromAnother(this);
}

/// When it has been cancelled. It should not be handled.
class ResultCancelled<T> extends Result<T> {
  /// Creates a new result cancelled instance.
  const ResultCancelled();

  /// Creates a new result cancelled instance from another [result].
  ResultCancelled.fromAnother(ResultCancelled result) : this();

  @override
  ResultCancelled<U> to<U>(_) => ResultCancelled<U>.fromAnother(this);
}

/// Allows to display a result into a SnackBar.
extension DisplayResult on BuildContext {
  /// Display the given [result].
  void handleResult(
    Result result, {
    bool showDialogIfError = true,
    String? successMessage,
  }) {
    switch (result) {
      case ResultSuccess():
        showSuccessToast(this, text: successMessage ?? translations.error.noError);
        break;
      case ResultError(:final exception, :final stackTrace):
        if (showDialogIfError) {
          ErrorDialog.openDialog(
            this,
            error: exception,
            stackTrace: stackTrace,
            allowRetry: false,
          );
          break;
        }
        showErrorToast(this, text: translations.error.generic.withException(exception: exception));
        break;
      default:
        break;
    }
  }
}
