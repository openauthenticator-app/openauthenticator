import 'package:flutter/material.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/logo_search/widget.dart';

/// Allows to pick a logo coming from a remote server.
class LogoPickerDialog extends StatelessWidget {
  /// The initial search keywords to use.
  final String? initialSearchKeywords;

  /// Triggered when a logo has been clicked.
  final ValueChanged<String>? onLogoClicked;

  /// Creates a new logo picker dialog instance.
  const LogoPickerDialog({
    super.key,
    this.initialSearchKeywords,
    this.onLogoClicked,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.logoSearch.dialogTitle),
    actions: [
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      LogoSearch(
        initialSearchKeywords: initialSearchKeywords,
        onLogoClicked: onLogoClicked,
      ),
    ],
  );

  /// Opens the dialog.
  static Future<String?> openDialog(
    BuildContext context, {
    String? initialSearchKeywords,
  }) => showDialog<String>(
    context: context,
    builder: (context) => LogoPickerDialog(
      initialSearchKeywords: initialSearchKeywords,
      onLogoClicked: (logo) => Navigator.pop(context, logo),
    ),
  );
}
