import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Allows to handle email confirmation.
class EmailConfirmationUtils {
  /// Asks for email confirmation.
  static Future<Result> askForConfirmation(
    BuildContext context,
    WidgetRef ref, {
    bool handleResult = true,
  }) async {
    _ConfirmAction? confirmAction = await _ConfirmActionPickerDialog.openDialog(context);
    if (confirmAction == null || !context.mounted) {
      return const ResultCancelled();
    }
    switch (confirmAction) {
      case _ConfirmAction.tryConfirm:
        Result result = await _tryConfirm(context, ref);
        if (handleResult && context.mounted) {
          context.handleResult(
            result,
            successMessage: result.valueOrNull?.localizedMessage,
          );
        }
        return result;
      case _ConfirmAction.cancelConfirmation:
        Result result = await _tryCancelConfirmation(context, ref);
        if (handleResult && context.mounted) {
          context.handleResult(result);
        }
        return result;
    }
  }

  /// Tries to cancel the confirmation.
  static Future<Result> _tryCancelConfirmation(BuildContext context, WidgetRef ref, {bool handleResult = true}) async {
    bool confirmation = await ConfirmationDialog.ask(
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
  static Future<Result<RedirectResult>> _tryConfirm(BuildContext context, WidgetRef ref) async {
    String? code = (await TextInputDialog.prompt(
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

/// Picks for a confirmation action.
class _ConfirmActionPickerDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.emailConfirmation.confirmActionPickerDialog.title),
    actions: [
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      ClickableTile(
        prefix: const Icon(FIcons.check),
        title: Text(translations.emailConfirmation.confirmActionPickerDialog.confirm.title),
        subtitle: Text(translations.emailConfirmation.confirmActionPickerDialog.confirm.subtitle),
        onPress: () => Navigator.pop(context, _ConfirmAction.tryConfirm),
      ),
      ClickableTile(
        variant: .destructive,
        prefix: const Icon(FIcons.x),
        title: Text(translations.emailConfirmation.confirmActionPickerDialog.cancelConfirmation.title),
        subtitle: Text(translations.emailConfirmation.confirmActionPickerDialog.cancelConfirmation.subtitle),
        onPress: () => Navigator.pop(context, _ConfirmAction.cancelConfirmation),
      ),
    ],
  );

  /// Opens the dialog.
  static Future<_ConfirmAction?> openDialog(BuildContext context) => showFDialog<_ConfirmAction>(
    context: context,
    builder: (context, style, animation) => _ConfirmActionPickerDialog(),
  );
}

/// A [_ConfirmActionPickerDialog] result.
enum _ConfirmAction {
  /// Tries to confirm the account.
  tryConfirm,

  /// Cancels the confirmation.
  cancelConfirmation,
}
