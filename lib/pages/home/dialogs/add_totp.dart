part of '../page.dart';

/// A dialog that allows to choose a method to add a TOTP.
class _AddTotpDialog extends StatelessWidget {
  /// Whether this dialog is supported on the current platform.
  static final bool isSupported = currentPlatform.isMobile;

  /// Creates a new add totp dialog instance.
  const _AddTotpDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.home.addDialog.title),
    actions: [
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      ClickableTile(
        prefix: const Icon(FIcons.qrCode),
        onPress: () => Navigator.pop(context, AddTotpDialogResult.qrCode),
        title: Text(translations.home.addDialog.qrCode.title),
        subtitle: Text(translations.home.addDialog.qrCode.subtitle),
      ),
      ClickableTile(
        prefix: const Icon(FIcons.textAlignStart),
        onPress: () => Navigator.pop(context, AddTotpDialogResult.manually),
        title: Text(translations.home.addDialog.manually.title),
        subtitle: Text(translations.home.addDialog.manually.subtitle),
      ),
    ],
  );

  /// Displays the [_AddTotpDialog].
  static Future<AddTotpDialogResult?> show(BuildContext context) async => await showDialog<AddTotpDialogResult>(
    context: context,
    builder: (context) => const _AddTotpDialog(),
  );
}

/// The [_AddTotpDialog] result.
enum AddTotpDialogResult {
  /// When the user wants to use a QR code to add a TOTP.
  qrCode,

  /// When the user wants to manually add the TOTP.
  manually,
}
