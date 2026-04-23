part of '../page.dart';

/// Allows the user to choose an action to execute when a TOTP decryption has been done with success.
class _TotpDecryptDialog extends StatelessWidget {
  /// Contains all decrypted TOTPs.
  final List<DecryptedTotp> decryptedTotps;

  /// Creates a new TOTP key dialog instance.
  const _TotpDecryptDialog({
    super.key,
    this.decryptedTotps = const [],
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.totp.totpKeyDialog.title),
    actions: [
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: kSpace),
        child: Text(
          translations.totp.totpKeyDialog.message(n: decryptedTotps.length),
        ),
      ),
      if (decryptedTotps.length > 1)
        ClickableTile(
          prefix: const Icon(FIcons.checkCheck),
          onPress: () => Navigator.pop(context, TotpDecryptDialogResult.changeAllTotpsKey),
          title: Text(translations.totp.totpKeyDialog.choices.changeAllDecryptedTotpsKey.title),
          subtitle: Text(translations.totp.totpKeyDialog.choices.changeAllDecryptedTotpsKey.subtitle),
        ),
      ClickableTile(
        prefix: const Icon(FIcons.keyRound),
        onPress: () => Navigator.pop(context, TotpDecryptDialogResult.changeTotpKey),
        title: Text(translations.totp.totpKeyDialog.choices.changeTotpKey.title(n: decryptedTotps.length)),
        subtitle: Text(translations.totp.totpKeyDialog.choices.changeTotpKey.subtitle),
      ),
      ClickableTile(
        prefix: const Icon(FIcons.rectangleEllipsis),
        onPress: () => Navigator.pop(context, TotpDecryptDialogResult.changeMasterPassword),
        title: Text(translations.totp.totpKeyDialog.choices.changeMasterPassword.title),
        subtitle: Text(translations.totp.totpKeyDialog.choices.changeMasterPassword.subtitle),
      ),
      ClickableTile(
        prefix: const Icon(FIcons.x),
        onPress: () => Navigator.pop(context),
        title: Text(translations.totp.totpKeyDialog.choices.doNothing.title),
        subtitle: Text(translations.totp.totpKeyDialog.choices.doNothing.subtitle),
      ),
    ],
  );

  /// Displays the [_TotpDecryptDialog].
  static Future<TotpDecryptDialogResult?> show(
    BuildContext context, {
    required List<DecryptedTotp> decryptedTotps,
  }) async => await showFDialog<TotpDecryptDialogResult>(
    context: context,
    builder: (context, style, animation) => _TotpDecryptDialog(
      decryptedTotps: decryptedTotps,
    ),
  );
}

/// The [_TotpDecryptDialog] result.
enum TotpDecryptDialogResult {
  /// Allows to change the TOTP key.
  changeTotpKey,

  /// Allows to change all TOTPs key (the current one and those that have been decrypted additionally).
  changeAllTotpsKey,

  /// Allows to change the current master password.
  changeMasterPassword,
}
