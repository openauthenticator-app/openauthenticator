import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/flows/app_flow.dart';
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

/// The account flow provider.
final accountFlowProvider = Provider.autoDispose<AccountFlow>(AccountFlow.new);

/// Coordinates account-related user flows.
class AccountFlow extends AppFlow {
  /// Creates a new account flow instance.
  const AccountFlow(super.ref);

  /// Prompts the user to choose an authentication provider, and use it to login.
  Future<Result> tryRequestSignIn(BuildContext context) => keepAliveWhile(() async {
    SignInDialogAction? action = await SignInDialog.openDialog(context);
    if (action == null || !context.mounted) {
      return const ResultCancelled();
    }
    return await _tryTo(
      context,
      waitingDialogMessage: translations.authentication.logIn.waitingLoginMessage,
      action: action,
      presentation: .errorDialog,
    );
  });

  /// Prompts the user to choose an authentication provider, and use it to link or unlink its current account.
  Future<Result> tryRequestToggleLink(BuildContext context) => keepAliveWhile(() async {
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
      presentation: .errorDialog,
    );
  });

  /// Prompts the user to choose an authentication provider, use it to re-authenticate and delete its account.
  Future<Result> tryDeleteAccount(BuildContext context) => keepAliveWhile(() async {
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
  });

  /// Tries to do the specified [action].
  Future<Result> _tryTo(
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
