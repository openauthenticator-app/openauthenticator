import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/flows/account.dart';
import 'package:open_authenticator/flows/storage_migration.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// A dialog that asks the user to log-in because of an invalid session.
class InvalidSessionDialog extends ConsumerWidget {
  /// Creates a new invalid session dialog instance.
  const InvalidSessionDialog._({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppDialog(
    title: Text(translations.authentication.invalidSessionDialog.title),
    actions: [
      ClickableButton(
        onPress: () => Navigator.pop(context, InvalidSessionDialogChoice.logIn),
        child: ButtonText(translations.authentication.invalidSessionDialog.button.logIn),
      ),
      ClickableButton(
        variant: .destructive,
        onPress: () => Navigator.pop(context, InvalidSessionDialogChoice.logOut),
        child: ButtonText(translations.authentication.invalidSessionDialog.button.logOut),
      ),
    ],
    children: [
      Text(translations.authentication.invalidSessionDialog.message),
    ],
  );

  /// Opens the invalid session dialog.
  static Future<InvalidSessionDialogChoice?> openDialog(BuildContext context, WidgetRef ref, {bool handleResult = false}) async {
    InvalidSessionDialogChoice? result = await showFDialog<InvalidSessionDialogChoice>(
      context: context,
      builder: (context, style, animation) => const InvalidSessionDialog._(),
    );
    if (!handleResult || !context.mounted) {
      return result;
    }
    switch (result) {
      case .logIn:
        await ref.read(accountFlowProvider).tryRequestSignIn(context);
        break;
      case .logOut:
        await ref.read(storageMigrationFlowProvider).changeStorageType(context, .localOnly, logout: true);
        break;
      default:
        break;
    }
    return result;
  }
}

/// The invalid session dialog result.
enum InvalidSessionDialogChoice {
  /// The user wants to log-in.
  logIn,

  /// The user wants to log-out.
  logOut,
}
