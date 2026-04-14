import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Allows the user to confirm its email from the app.
class ConfirmEmailSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new confirm email settings entry widget instance.
  const ConfirmEmailSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<EmailConfirmationData?> emailToConfirm = ref.watch(emailConfirmationStateProvider);
    if (emailToConfirm.value == null) {
      return const SizedBox.shrink();
    }
    return ClickableTile(
      prefix: const Icon(FIcons.mail),
      suffix: const RightChevronSuffix(),
      title: Text(translations.settings.synchronization.confirmEmail.title),
      subtitle: Text.rich(
        translations.settings.synchronization.confirmEmail.subtitle(
          email: TextSpan(
            text: emailToConfirm.value!.email,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ),
      onPress: () async {
        _ConfirmAction? confirmAction = await _ConfirmActionPickerDialog.openDialog(context);
        if (confirmAction == null || !context.mounted) {
          return;
        }
        switch (confirmAction) {
          case _ConfirmAction.tryConfirm:
            _tryConfirm(context, ref);
            break;
          case _ConfirmAction.cancelConfirmation:
            _tryCancelConfirmation(context, ref);
            break;
        }
      },
    );
  }

  /// Tries to cancel the confirmation.
  Future<void> _tryCancelConfirmation(BuildContext context, WidgetRef ref) async {
    bool confirmation = await ConfirmationDialog.ask(
      context,
      title: translations.settings.synchronization.confirmEmail.confirmActionPickerDialog.cancelConfirmation.validationDialog.title,
      message: translations.settings.synchronization.confirmEmail.confirmActionPickerDialog.cancelConfirmation.validationDialog.message,
      okButtonVariant: .destructive,
    );
    if (!confirmation || !context.mounted) {
      return;
    }
    Result result = await showWaitingOverlay(
      context,
      future: ref.read(authenticationProviders).email.cancelConfirmation(),
    );
    if (context.mounted) {
      context.handleResult(result);
    }
  }

  /// Tries to confirm the user. He has to enter the code manually.
  Future<void> _tryConfirm(BuildContext context, WidgetRef ref) async {
    String? code = await TextInputDialog.prompt(
      context,
      title: translations.settings.synchronization.confirmEmail.codeDialog.title,
      message: translations.settings.synchronization.confirmEmail.codeDialog.message,
      keyboardType: .visiblePassword,
      textCapitalization: .characters,
    );
    if (code == null || !context.mounted) {
      return;
    }
    Result<RedirectResult> result = await ref.read(authenticationProviders).email.confirm(code);
    if (context.mounted) {
      context.handleResult(
        result,
        successMessage: result.valueOrNull?.localizedMessage,
      );
    }
  }
}

/// Picks for a confirmation action.
class _ConfirmActionPickerDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.settings.synchronization.confirmEmail.confirmActionPickerDialog.title),
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
        title: Text(translations.settings.synchronization.confirmEmail.confirmActionPickerDialog.confirm.title),
        subtitle: Text(translations.settings.synchronization.confirmEmail.confirmActionPickerDialog.confirm.subtitle),
        onPress: () => Navigator.pop(context, _ConfirmAction.tryConfirm),
      ),
      ClickableTile(
        variant: .destructive,
        prefix: const Icon(FIcons.x),
        title: Text(translations.settings.synchronization.confirmEmail.confirmActionPickerDialog.cancelConfirmation.title),
        subtitle: Text(translations.settings.synchronization.confirmEmail.confirmActionPickerDialog.cancelConfirmation.subtitle),
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
