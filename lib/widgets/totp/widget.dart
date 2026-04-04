import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/totp/code.dart';
import 'package:open_authenticator/widgets/totp/image.dart';

/// Allows to display TOTPs in a [ListView].
class TotpTile extends StatelessWidget {
  /// The default image size.
  static const double _kDefaultImageSize = 70;

  /// The TOTP instance.
  final Totp totp;

  /// The TOTP image size.
  final double imageSize;

  /// Whether to display the code.
  final bool displayCode;

  /// Triggered when tapped.
  final Function(BuildContext context)? onTap;

  /// Triggered when long pressed.
  final Function(BuildContext context)? onLongPress;

  /// the trailing widget builder.
  final WidgetBuilder? suffixBuilder;

  /// Creates a new TOTP widget instance that adapts itself to the current platform.
  TotpTile.adaptive({
    Key? key,
    required Totp totp,
    double imageSize = _kDefaultImageSize,
    bool displayCode = true,
    Function(BuildContext context)? onTap,
    VoidCallback? onDecryptPress,
    VoidCallback? onEditPress,
    VoidCallback? onDeletePress,
    VoidCallback? onCopyPress,
  }) : this(
         key: key,
         totp: totp,
         imageSize: imageSize,
         displayCode: displayCode,
         onTap: onTap,
         suffixBuilder: _adaptiveSuffixBuilder(
           totp: totp,
           onCopyPress: onCopyPress,
           onDecryptPress: onDecryptPress,
           onEditPress: onEditPress,
           onDeletePress: onDeletePress,
         ),
         onLongPress: _adaptiveOnLongPress(
           totp: totp,
           onEditPress: onEditPress,
           onDeletePress: onDeletePress,
         ),
       );

  /// Creates a new TOTP widget instance.
  const TotpTile({
    super.key,
    required this.totp,
    this.imageSize = _kDefaultImageSize,
    this.displayCode = true,
    this.onTap,
    this.onLongPress,
    this.suffixBuilder,
  });

  @override
  Widget build(BuildContext context) => ClickableTile(
    prefix: totp.isDecrypted
        ? TotpCountdownImage(
            totp: totp,
            size: imageSize,
          )
        : TotpImage.fromTotp(
            totp: totp,
            size: imageSize,
          ),
    onLongPress: onLongPress == null ? null : (() => onLongPress!.call(context)),
    onPress: onTap == null ? null : (() => onTap!.call(context)),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totp.isDecrypted && (totp as DecryptedTotp).issuer != null && (totp as DecryptedTotp).issuer!.isNotEmpty)
          Text(
            ((totp as DecryptedTotp)).issuer!,
            style: context.theme.typography.lg.copyWith(
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Text(
          (totp.isDecrypted ? (totp as DecryptedTotp).label : null) ?? totp.uuid,
          style: context.theme.typography.md.copyWith(
            color: context.theme.colors.mutedForeground,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    subtitle: totp.isDecrypted && displayCode
        ? Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TotpCode(
              totp: totp as DecryptedTotp,
              textStyle: context.theme.typography.xl2,
            ),
          )
        : null,
    suffix: suffixBuilder?.call(context),
  );

  /// The adaptive suffix builder.
  static WidgetBuilder? _adaptiveSuffixBuilder({
    required Totp totp,
    VoidCallback? onCopyPress,
    VoidCallback? onDecryptPress,
    VoidCallback? onEditPress,
    VoidCallback? onDeletePress,
  }) {
    if (currentPlatform.isDesktop) {
      return (context) => _DesktopActions(
        totp: totp,
        onDecryptPress: onDecryptPress,
        onEditPress: onEditPress,
        onDeletePress: onDeletePress,
      );
    }
    if (totp.isDecrypted) {
      return onCopyPress == null
          ? null
          : (context) => ClickableButton.icon(
              variant: .secondary,
              onPress: onCopyPress,
              child: const Icon(FIcons.copy),
            );
    } else {
      return onDecryptPress == null
          ? null
          : (context) => ClickableButton.icon(
              variant: .secondary,
              onPress: onDecryptPress,
              child: const Icon(FIcons.lock),
            );
    }
  }

  /// The adaptive on long press listener.
  static Function(BuildContext)? _adaptiveOnLongPress({
    required Totp totp,
    VoidCallback? onEditPress,
    VoidCallback? onDeletePress,
  }) => _MobileActionsDialog.isSupported || kDebugMode
      ? ((context) => _showMobileActionsMenu(
          context,
          totp,
          onEditPress: onEditPress,
          onDeletePress: onDeletePress,
        ))
      : null;

  /// Triggered when the user long presses the widget on mobile.
  static Future<void> _showMobileActionsMenu(
    BuildContext context,
    Totp totp, {
    VoidCallback? onEditPress,
    VoidCallback? onDeletePress,
  }) async {
    _MobileActionsDialogResult? choice = await showFDialog<_MobileActionsDialogResult>(
      context: context,
      builder: (context, style, animation) => _MobileActionsDialog(
        canEdit: totp.isDecrypted,
        editButtonEnabled: onEditPress != null,
        deleteButtonEnabled: onDeletePress != null,
      ),
    );
    if (choice == null || !context.mounted) {
      return;
    }
    switch (choice) {
      case _MobileActionsDialogResult.edit:
        onEditPress?.call();
        break;
      case _MobileActionsDialogResult.delete:
        onDeletePress?.call();
        break;
    }
  }
}

/// Wraps all two mobile actions in a dialog.
class _MobileActionsDialog extends StatelessWidget {
  /// Whether this dialog is supported on the current platform.
  static final bool isSupported = currentPlatform.isMobile;

  /// Whether the user can edit the TOTP.
  final bool canEdit;

  /// Whether the "edit" button can been pressed.
  final bool editButtonEnabled;

  /// Whether the "delete" button can been pressed.
  final bool deleteButtonEnabled;

  /// Creates a new mobile actions dialog instance.
  const _MobileActionsDialog({
    this.canEdit = true,
    this.editButtonEnabled = true,
    this.deleteButtonEnabled = true,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.totp.actions.mobileDialog.title),
    actions: [
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      if (canEdit)
        ClickableTile(
          prefix: const Icon(FIcons.pencil),
          onPress: editButtonEnabled ? (() => Navigator.pop(context, _MobileActionsDialogResult.edit)) : null,
          title: Text(translations.totp.actions.mobileDialog.edit),
        ),
      ClickableTile(
        prefix: const Icon(FIcons.trash),
        onPress: deleteButtonEnabled ? (() => Navigator.pop(context, _MobileActionsDialogResult.delete)) : null,
        title: Text(translations.totp.actions.mobileDialog.delete),
      ),
    ],
  );
}

/// The [_MobileActionsDialog] result.
enum _MobileActionsDialogResult {
  /// When the user wants to edit the TOTP.
  edit,

  /// When the user wants to delete the TOTP.
  delete,
}

/// Wraps all three desktop actions in a widget.
class _DesktopActions extends StatelessWidget {
  /// The TOTP instance.
  final Totp totp;

  /// Triggered when the user clicks on "Decrypt".
  final VoidCallback? onDecryptPress;

  /// Triggered when the user clicks on "Edit".
  final VoidCallback? onEditPress;

  /// Triggered when the user clicks on "Delete".
  final VoidCallback? onDeletePress;

  /// Creates a new desktop actions instance.
  const _DesktopActions({
    required this.totp,
    this.onDecryptPress,
    this.onEditPress,
    this.onDeletePress,
  });

  @override
  Widget build(BuildContext context) => FPopoverMenu(
    autofocus: true,
    menu: [
      FItemGroup(
        children: [
          if (totp.isDecrypted) ...[
            Clickable(
              child: FItem(
                onPress: onEditPress,
                prefix: const Icon(FIcons.pencil),
                title: Text(translations.totp.actions.desktopButtons.edit),
              ),
            ),
            Clickable(
              child: FItem(
                style: .delta(
                  contentStyle: .delta(
                    prefixIconStyle: .delta(
                      [
                        .all(
                          .delta(color: context.theme.colors.destructive),
                        ),
                      ],
                    ),
                  ),
                ),
                onPress: onDeletePress,
                prefix: const Icon(FIcons.trash),
                title: Text(translations.totp.actions.desktopButtons.delete),
              ),
            ),
          ] else
            Clickable(
              child: FItem(
                onPress: onDecryptPress,
                prefix: const Icon(FIcons.lock),
                title: Text(translations.totp.actions.decrypt),
              ),
            ),
        ],
      ),
    ],
    child: const Icon(FIcons.ellipsis),
    builder: (_, controller, child) => ClickableButton.icon(
      variant: .ghost,
      onPress: controller.toggle,
      child: child!,
    ),
  );
}
