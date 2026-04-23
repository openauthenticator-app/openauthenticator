import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/error.dart';

/// A dialog displaying an error with the option to retry.
class ErrorDialog extends StatelessWidget {
  /// The additional message to display.
  final String? message;

  /// The error.
  final Object? error;

  /// The stacktrace.
  final StackTrace stackTrace;

  /// Whether to allow retry.
  final bool allowRetry;

  /// Creates a new error display widget instance.
  const ErrorDialog({
    super.key,
    this.message,
    this.error,
    required this.stackTrace,
    this.allowRetry = true,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.error.widget.title),
    actions: [
      if (allowRetry)
        ClickableButton(
          variant: .secondary,
          onPress: () => Navigator.pop(context, ErrorDialogResult.retry),
          child: ButtonText(translations.error.widget.button.retry),
        ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context, ErrorDialogResult.cancel),
        child: ButtonText(allowRetry ? MaterialLocalizations.of(context).cancelButtonLabel : MaterialLocalizations.of(context).closeButtonLabel),
      ),
    ],
    children: [
      ErrorWithStackTrace(
        error: error,
        stackTrace: stackTrace,
        message: message,
      ),
    ],
  );

  /// Opens the dialog.
  static Future<ErrorDialogResult?> openDialog(
    BuildContext context, {
    String? message,
    Object? error,
    StackTrace? stackTrace,
    bool allowRetry = false,
  }) => showFDialog<ErrorDialogResult>(
    context: context,
    builder: (context, style, animation) => ErrorDialog(
      message: message,
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
      allowRetry: allowRetry,
    ),
  );
}

/// The result of the error dialog.
enum ErrorDialogResult {
  /// The user pressed cancel.
  cancel,

  /// The user pressed report.
  retry,
}
