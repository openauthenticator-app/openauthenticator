import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/utils/app_unlock_interaction.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/presentation.dart' show ResultPresentation;
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/dialog/sign_in_dialog.dart';
import 'package:open_authenticator/widgets/dialog/toggle_link_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Contains some useful methods for logging and linking the user's current account.
class AccountUtils {
  /// Prompts the user to choose an authentication provider, and use it to login.
  static Future<Result> tryRequestSignIn(BuildContext context) async {
    SignInDialogAction? action = await SignInDialog.openDialog(context);
    if (action == null || !context.mounted) {
      return const ResultCancelled();
    }
    return await _tryTo(
      context,
      waitingDialogMessage: translations.authentication.logIn.waitingLoginMessage,
      action: action,
      presentation: ResultPresentation.errorDialog,
    );
  }

  /// Prompts the user to choose an authentication provider, and use it to link or unlink its current account.
  static Future<Result> tryRequestToggleLink(BuildContext context) async {
    ToggleLinkDialogResult? result = await ToggleLinkDialog.openDialog(context);
    if (result == null || !context.mounted) {
      return const ResultCancelled();
    }
    bool unlink = !result.link;
    if (unlink &&
        !(await ConfirmationDialog.ask(
          context,
          title: translations.authentication.link.unlinkConfirmationDialog.title,
          message: translations.authentication.link.unlinkConfirmationDialog.message,
          okButtonVariant: .destructive,
        ))) {
      return const ResultCancelled();
    }
    if (!context.mounted) {
      return const ResultCancelled();
    }
    return await _tryTo(
      context,
      waitingDialogMessage: unlink ? null : translations.authentication.logIn.waitingLoginMessage,
      action: result.action,
      presentation: ResultPresentation.errorDialog,
    );
  }

  /// Prompts the user to choose an authentication provider, use it to re-authenticate and delete its account.
  static Future<Result> tryDeleteAccount(BuildContext context, WidgetRef ref) async {
    bool confirm = await ConfirmationDialog.ask(
      context,
      title: translations.authentication.deleteConfirmationDialog.title,
      message: translations.authentication.deleteConfirmationDialog.message,
      okButtonVariant: .destructive,
    );
    if (!confirm || !context.mounted) {
      return const ResultCancelled();
    }

    AppUnlockMethodSettingsEntry appUnlockerMethodsSettingsEntry = ref.read(appUnlockMethodSettingsEntryProvider.notifier);
    Result unlockResult = await appUnlockerMethodsSettingsEntry.unlockWithCurrentMethod(context.appUnlockInteraction, UnlockReason.sensibleAction);
    if (unlockResult is! ResultSuccess || !context.mounted) {
      return unlockResult;
    }
    if (!context.mounted) {
      return const ResultCancelled();
    }
    return _tryTo(
      context,
      action: () => ref.read(userProvider.notifier).deleteUser(),
    );
  }

  /// Tries to do the specified [action].
  static Future<Result> _tryTo(
    BuildContext context, {
    required Future<Result> Function() action,
    String? waitingDialogMessage,
    ResultPresentation presentation = .successAndErrorDialog,
  }) async {
    Result result = await showWaitingOverlay(
      context,
      future: action(),
      message: waitingDialogMessage,
    );
    if (context.mounted) {
      handleResult(
        context,
        result,
        presentation: presentation,
      );
    }
    return result;
  }
}
