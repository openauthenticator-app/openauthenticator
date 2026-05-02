import 'package:flutter/material.dart';
import 'package:open_authenticator/utils/result/presentation.dart';
import 'package:open_authenticator/utils/result/reporter.dart';
import 'package:open_authenticator/utils/result/result.dart';

/// Handles the [result] with the given [presentation] and [reporting].
void handleResult<T>(
  BuildContext context,
  Result<T> result, {
  ResultPresentation presentation = .successAndErrorDialog,
  ResultReporting reporting = .consoleAndSentry,
  MessageBuilder<T>? buildSuccessToastMessage,
  MessageBuilder<Object?>? buildErrorToastMessage,
  MessageBuilder<Object?>? buildErrorDialogMessage,
}) {
  reportResult(result, reporting: reporting);
  switch (presentation) {
    case .none:
      break;
    case .successToast:
      result.showSuccessToast(context, buildSuccessToastMessage);
      break;
    case .errorDialog:
      result.showErrorDialog(context, buildErrorDialogMessage);
      break;
    case .errorToast:
      result.showErrorToast(context, buildErrorToastMessage);
      break;
    case .successAndErrorDialog:
      result.showSuccessToast(context, buildSuccessToastMessage);
      result.showErrorDialog(context, buildErrorDialogMessage);
      break;
    case .successAndErrorToast:
      result.showSuccessToast(context, buildSuccessToastMessage);
      result.showErrorToast(context, buildErrorToastMessage);
      break;
  }
}
