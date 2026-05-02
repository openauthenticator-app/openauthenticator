import 'package:flutter/material.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/toast.dart' as toast;

/// How a [Result] should be presented to the user.
enum ResultPresentation {
  /// Does not present anything to the user.
  none,

  /// Shows [ResultSuccess] with a success toast.
  successToast,

  /// Shows [ResultError] with an error dialog.
  errorDialog,

  /// Shows [ResultError] with an error toast.
  errorToast,

  /// Shows [ResultSuccess] with a success toast and [ResultError] with an error dialog.
  successAndErrorDialog,

  /// Shows [ResultSuccess] with a success toast and [ResultError] with an error toast.
  successAndErrorToast,
}

/// A message builder.
typedef MessageBuilder<T> = String? Function(T? argument);

/// Allows to present a [Result] to the user.
extension PresentResult<T> on Result<T> {
  /// Shows a success toast for a [ResultSuccess].
  void showSuccessToast(BuildContext context, MessageBuilder<T>? successMessage) {
    if (this is ResultSuccess<T>) {
      toast.showSuccessToast(
        context,
        text: successMessage?.call(valueOrNull) ?? translations.error.noError,
      );
    }
  }

  /// Shows an error toast for a [ResultError].
  void showErrorToast(BuildContext context, MessageBuilder<Object?>? errorMessage) {
    if (this is ResultError) {
      String? message = errorMessage?.call((this as ResultError).exception);
      if (message == null) {
        if ((this as ResultError).exception is LocalizableException) {
          message = ((this as ResultError).exception as LocalizableException).localizedErrorMessage;
        }
        message ??= translations.error.generic.withException(exception: (this as ResultError).exception);
      }
      toast.showErrorToast(
        context,
        text: message,
      );
    }
  }

  /// Shows an error dialog for a [ResultError].
  void showErrorDialog(BuildContext context, MessageBuilder<Object?>? errorMessage) {
    if (this is ResultError) {
      String? message = errorMessage?.call((this as ResultError).exception);
      ErrorDialog.openDialog(
        context,
        error: (this as ResultError).exception,
        stackTrace: (this as ResultError).stackTrace,
        message: message,
      );
    }
  }
}
