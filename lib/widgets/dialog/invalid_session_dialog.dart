import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/utils/storage_migration.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// A dialog that asks the user to log-in because of an invalid session.
class InvalidSessionDialog extends ConsumerWidget {
  /// Whether to automatically handle the result.
  final bool handleResult;

  const InvalidSessionDialog._({
    super.key,
    this.handleResult = false,
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
        onPress: () => Navigator.pop(context),
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
        await AccountUtils.tryRequestSignIn(context);
        break;
      case .logOut:
        await StorageMigrationUtils.changeStorageType(context, ref, .localOnly, logout: true);
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
