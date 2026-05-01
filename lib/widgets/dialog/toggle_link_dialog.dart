import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/utils/brightness_listener.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/authentication_provider_image.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/invert_colors.dart';

/// Represents a toggle link dialog action.
typedef ToggleLinkDialogResult = ({Future<Result> Function() action, bool link});

/// Allows to pick an authentication provider.
class ToggleLinkDialog extends ConsumerWidget {
  /// Creates a new authentication picker dialog instance.
  const ToggleLinkDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<AuthenticationProvider> providers = ref.watch(authenticationProviders);
    List<AuthenticationProvider> currentProviders = ref.watch(userAuthenticationProviders);
    EmailConfirmationData? confirmationData = ref.watch(emailConfirmationStateProvider).value;
    Widget createTile(AuthenticationProvider provider) {
      bool unlink = currentProviders.contains(provider);
      return _ProviderTile(
        providerId: provider.id,
        trailingIcon: unlink ? FIcons.unlink : null,
        onTap: () => Navigator.pop(
          context,
          (
            action: unlink
                ? provider.unlink
                : (() async {
                    switch (provider) {
                      case EmailAuthenticationProvider():
                        String? email = await TextInputDialog.prompt(
                          context,
                          title: translations.authentication.emailDialog.title,
                          message: translations.authentication.emailDialog.message,
                          validator: TextInputDialog.validateEmail,
                          keyboardType: TextInputType.emailAddress,
                        );
                        if (email == null || !context.mounted) {
                          return const ResultCancelled();
                        }
                        return provider.requestLinking(email);
                      case OAuthenticationProvider():
                        return provider.requestLinking();
                    }
                  }),
            link: !unlink,
          ),
        ),
      );
    }

    return AppDialog(
      title: Text(translations.authentication.providerPickerDialogTitle),
      actions: [
        ClickableButton(
          variant: .secondary,
          onPress: () => Navigator.pop(context),
          child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
      children: [
        for (AuthenticationProvider provider in providers)
          if (currentProviders.length != 1 || provider != currentProviders.first)
            if (provider is! EmailAuthenticationProvider || confirmationData == null) createTile(provider),
      ],
    );
  }

  /// Opens the dialog.
  static Future<ToggleLinkDialogResult?> openDialog(BuildContext context) => showFDialog<ToggleLinkDialogResult>(
    context: context,
    builder: (context, style, animation) => const ToggleLinkDialog(),
  );
}

/// An [AuthenticationProvider] tile.
class _ProviderTile extends ConsumerStatefulWidget {
  /// The provider.
  final String providerId;

  /// The icon size.
  final double size;

  /// The icon to append when needed.
  final IconData? trailingIcon;

  /// Triggered when tapped on.
  final VoidCallback? onTap;

  /// Creates a new provider tile instance.
  const _ProviderTile({
    required this.providerId,
    this.size = 32,
    this.trailingIcon,
    this.onTap,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ProviderTileState();
}

/// The provider tile state.
class _ProviderTileState extends ConsumerState<_ProviderTile> with BrightnessListener {
  @override
  Widget build(BuildContext context) {
    Widget image = AuthenticationProviderImage(
      providerId: widget.providerId,
      width: widget.size,
      height: widget.size,
    );
    bool invertIconOnBrightnessChance =
        widget.providerId == EmailAuthenticationProvider.kProviderId ||
        widget.providerId == AppleAuthenticationProvider.kProviderId ||
        // widget.providerId == TwitterAuthenticationProvider.kProviderId ||
        widget.providerId == GithubAuthenticationProvider.kProviderId;
    String? title = translations.authentication.authenticationProvider[widget.providerId].name;
    String? subtitle = translations.authentication.authenticationProvider[widget.providerId].description;
    return ClickableTile(
      prefix: invertIconOnBrightnessChance && currentBrightness == Brightness.dark ? InvertColors(child: image) : image,
      title: title == null ? const SizedBox.shrink() : Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      enabled: widget.onTap != null,
      onPress: widget.onTap,
      suffix: widget.trailingIcon == null ? null : Icon(widget.trailingIcon),
    );
  }
}
