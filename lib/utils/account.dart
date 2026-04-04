import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/dialog/authentication_provider_picker_dialog.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/dialog/sign_in_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Contains some useful methods for logging and linking the user's current account.
class AccountUtils {
  /// Prompts the user to choose an authentication provider, and use it to login.
  static Future<Result> trySignIn(BuildContext context) async {
    SignInDialogResult? result = await SignInDialog.openDialog(context);
    if (result == null || !context.mounted) {
      return const ResultCancelled();
    }
    return await _trySignInOrLink(
      context,
      successMessage: result.willNeedConfirmation ? translations.authentication.logIn.successNeedConfirmation : translations.authentication.logIn.success,
      waitingDialogMessage: translations.authentication.logIn.waitingLoginMessage,
      action: result.action,
    );
  }

  /// Prompts the user to choose an authentication provider, and use it to link or unlink its current account.
  static Future<Result> tryToggleLink(BuildContext context) async {
    AuthenticationProviderToggleLinkResult? result = await AuthenticationProviderPickerDialog.openDialog(context);
    if (result == null || !context.mounted) {
      return const ResultCancelled();
    }
    bool unlink = !result.link;
    if (unlink &&
        !(await ConfirmationDialog.ask(
          context,
          title: translations.authentication.link.unlinkConfirmationDialog.title,
          message: translations.authentication.link.unlinkConfirmationDialog.message,
        ))) {
      return const ResultCancelled();
    }
    if (!context.mounted) {
      return const ResultCancelled();
    }
    return await _trySignInOrLink(
      context,
      successMessage: unlink ? translations.authentication.link.unlinkSuccess : translations.authentication.link.linkSuccess,
      waitingDialogMessage: unlink ? null : translations.authentication.logIn.waitingLoginMessage,
      action: result.action,
    );
  }

  /// Prompts the user to choose an authentication provider, use it to re-authenticate and delete its account.
  static Future<Result> tryDeleteAccount(
    BuildContext context,
    WidgetRef ref, {
    bool handleResult = true,
  }) async {
    bool confirm = await ConfirmationDialog.ask(
      context,
      title: translations.authentication.deleteConfirmationDialog.title,
      message: translations.authentication.deleteConfirmationDialog.message,
    );
    if (!confirm || !context.mounted) {
      return const ResultCancelled();
    }

    AppUnlockMethodSettingsEntry appUnlockerMethodsSettingsEntry = ref.read(appUnlockMethodSettingsEntryProvider.notifier);
    Result unlockResult = await appUnlockerMethodsSettingsEntry.unlockWithCurrentMethod(context, UnlockReason.sensibleAction);
    if (unlockResult is! ResultSuccess || !context.mounted) {
      return unlockResult;
    }

    Result deleteResult = await showWaitingOverlay(
      context,
      future: ref.read(userProvider.notifier).deleteUser(),
    );
    if (handleResult && context.mounted) {
      context.handleResult(deleteResult);
    }
    return deleteResult;
  }

  /// Tries to do the specified [action].
  static Future<Result> _trySignInOrLink(
    BuildContext context, {
    required Future<Result> Function() action,
    String? successMessage,
    String? waitingDialogMessage,
    bool handleResult = true,
  }) async {
    Result result = await showWaitingOverlay(
      context,
      future: action(),
      message: waitingDialogMessage,
    );
    if (handleResult && context.mounted) {
      handleAuthenticationResult(
        context,
        result,
        successMessage: successMessage,
      );
    }
    return result;
  }

  /// Visually handles the [result].
  static void handleAuthenticationResult(
    BuildContext context,
    Result result, {
    String? successMessage,
  }) => context.handleResult(
    result,
    successMessage: successMessage ?? translations.authentication.logIn.success,
    showDialogIfError: (exception) => exception is InvalidVerificationCodeError,
  );
}
