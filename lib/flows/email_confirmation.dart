import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/flows/app_flow.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/presentation.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/dialog/email_confirmation_action_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// The email confirmation flow provider.
final Provider<EmailConfirmationFlow> emailConfirmationFlowProvider = Provider.autoDispose<EmailConfirmationFlow>(EmailConfirmationFlow.new);

/// Coordinates email confirmation user flows.
class EmailConfirmationFlow extends AppFlow {
  /// Creates a new email confirmation flow instance.
  const EmailConfirmationFlow(super.ref);

  /// Asks for email confirmation.
  Future<Result> askForConfirmation(
    BuildContext context, {
    ResultPresentation presentation = .successAndErrorDialog,
  }) => keepAliveWhile(() async {
    Result result;
    final EmailConfirmationAction? confirmAction = await EmailConfirmationActionPickerDialog.openDialog(context);
    if (confirmAction == null || !context.mounted) {
      result = const ResultCancelled();
    } else {
      result = await switch (confirmAction) {
        .tryConfirm => _tryConfirm(context),
        .cancelConfirmation => _tryCancelConfirmation(context),
      };
    }
    if (context.mounted) {
      handleResult(
        context,
        result,
        presentation: presentation,
        buildSuccessToastMessage: (value) => confirmAction == .tryConfirm ? (value as RedirectResult).localizedMessage : null,
      );
    }
    return result;
  });

  /// Tries to cancel the confirmation.
  Future<Result> _tryCancelConfirmation(BuildContext context) async {
    final bool confirmation = await ConfirmationDialog.ask(
      context,
      title: translations.emailConfirmation.confirmActionPickerDialog.cancelConfirmation.validationDialog.title,
      message: translations.emailConfirmation.confirmActionPickerDialog.cancelConfirmation.validationDialog.message,
      okButtonVariant: .destructive,
    );
    if (!confirmation || !context.mounted) {
      return const ResultCancelled();
    }
    return await showWaitingOverlay(
      context,
      future: ref.read(authenticationProviders).email.cancelConfirmation(),
    );
  }

  /// Tries to confirm the user. He has to enter the code manually.
  Future<Result<RedirectResult>> _tryConfirm(BuildContext context) async {
    final String? code = (await TextInputDialog.prompt(
      context,
      title: translations.emailConfirmation.codeDialog.title,
      message: translations.emailConfirmation.codeDialog.message,
      keyboardType: .visiblePassword,
      textCapitalization: .characters,
    ))?.trim();
    if (code == null || code.isEmpty || !context.mounted) {
      return const ResultCancelled();
    }
    return await showWaitingOverlay(
      context,
      future: ref.read(authenticationProviders).email.confirm(code),
    );
  }
}
