import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/form_label.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:open_authenticator/widgets/authentication_provider_image.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/divider_text.dart';

/// Allows to sign in in the user.
class SignInDialog extends ConsumerStatefulWidget {
  /// Creates a new sign-in dialog instance.
  const SignInDialog({
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SignInDialogState();

  /// Opens the dialog.
  static Future<SignInDialogResult?> openDialog(BuildContext context) => showDialog<SignInDialogResult>(
    context: context,
    builder: (context) => const SignInDialog(),
  );
}

/// The sign-in dialog state.
class _SignInDialogState extends ConsumerState<SignInDialog> {
  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.authentication.signInDialog.title),
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
        child: _EmailForm(
          onEmailValidated: (provider, email) {
            Navigator.pop(
              context,
              SignInDialogResult(
                action: () => ref.read(emailAuthenticationProvider).requestSignIn(email),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: kSpace),
        child: DividerText(
          text: Text(translations.authentication.signInDialog.separator),
        ),
      ),
      _OAuthenticationProvidersWrap(
        onProviderSelected: (provider) {
          Navigator.pop(
            context,
            SignInDialogResult(
              action: provider.requestSignIn,
            ),
          );
        },
      ),
    ],
  );
}

/// Represents a sign-in dialog action.
class SignInDialogResult {
  /// The action.
  final Future<Result> Function() action;

  /// Creates a new sign-in dialog result instance.
  const SignInDialogResult({
    required this.action,
  });
}

/// Displays the email form.
class _EmailForm extends ConsumerStatefulWidget {
  /// Triggered when an email has been validated.
  final Function(EmailAuthenticationProvider, String) onEmailValidated;

  /// Creates a new email form instance.
  const _EmailForm({
    required this.onEmailValidated,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EmailFormState();
}

/// The email form state.
class _EmailFormState extends ConsumerState<_EmailForm> {
  /// The email.
  String email = '';

  /// The email text editing controller.
  late final TextEditingController emailController = TextEditingController(text: email)
    ..addListener(() {
      if (mounted) {
        setState(() => email = emailController.text);
      }
    });

  @override
  Widget build(BuildContext context) {
    User? user = ref.watch(userProvider).value;
    EmailAuthenticationProvider provider = ref.watch(emailAuthenticationProvider);
    bool hasEmailProvider = user != null && user.hasAuthenticationProvider(provider.id);

    String? emailToConfirm = ref.watch(emailConfirmationStateProvider).value?.email;
    bool canAuthenticateByEmail = emailToConfirm == null && !hasEmailProvider;
    Widget child = Text(translations.authentication.signInDialog.email.button);
    String description = canAuthenticateByEmail ? translations.authentication.signInDialog.email.description.signIn : translations.authentication.signInDialog.email.description.cannotUse;
    if (emailToConfirm != null) {
      description = translations.authentication.signInDialog.email.description.waitingForConfirmation;
    } else if (hasEmailProvider) {
      child = _ButtonChildWithAuthenticatedBadge(child: child);
      description = translations.authentication.signInDialog.email.description.alreadySignedIn;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace / 2),
          child: FTextFormField(
            control: .managed(controller: emailController),
            enabled: canAuthenticateByEmail,
            label: FormLabelWithIcon(
              icon: FIcons.mail,
              text: translations.authentication.signInDialog.email.title,
            ),
            hint: emailToConfirm ?? (hasEmailProvider ? user.email : null) ?? translations.authentication.signInDialog.email.hint,
            textInputAction: TextInputAction.done,
            validator: TextInputDialog.validateEmail,
            keyboardType: TextInputType.emailAddress,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: kBigSpace),
          child: Text(
            description,
            style: context.theme.typography.xs,
          ),
        ),
        ClickableButton(
          prefix: const Icon(FIcons.send),
          onPress: email.trim().isNotEmpty && TextInputDialog.validateEmail(email) == null ? (() => onEmailChosen(provider)) : null,
          child: child,
        ),
      ],
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  /// Sends a mail confirmation.
  Future<void> onEmailChosen(EmailAuthenticationProvider provider) async {
    if (TextInputDialog.validateEmail(email) == null) {
      widget.onEmailValidated(provider, email);
    }
  }
}

/// Allows to display other providers.
class _OAuthenticationProvidersWrap extends ConsumerWidget {
  /// Triggered when a provider has been selected.
  final Function(OAuthenticationProvider) onProviderSelected;

  /// The circle button size.
  final double circleButtonSize;

  /// The space between two circle buttons.
  final double circleButtonSpace;

  /// A circle button inner padding.
  final double circleButtonPadding;

  /// Creates a new others providers wrap instance.
  const _OAuthenticationProvidersWrap({
    required this.onProviderSelected,
    this.circleButtonSize = 30,
    this.circleButtonSpace = 10,
    this.circleButtonPadding = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Iterable<OAuthenticationProvider> providers = ref.watch(
      authenticationProviders.select((providers) => providers.whereType<OAuthenticationProvider>()),
    );
    double circleLineWidth = providers.length * (circleButtonSize + circleButtonSpace * 2 + circleButtonPadding * 2);
    return LayoutBuilder(
      builder: (context, constraints) => circleLineWidth <= constraints.maxWidth && providers.length >= 3
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: circleButtonSpace,
              children: [
                for (OAuthenticationProvider provider in providers)
                  _ProviderCircleButton(
                    onTapIfLoggedOut: () => onProviderSelected(provider),
                    providerId: provider.id,
                    size: circleButtonSize,
                    padding: EdgeInsets.all(circleButtonPadding),
                  ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < providers.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i < providers.length - 1 ? 10 : 0),
                    child: _ProviderButton(
                      onPressIfLoggedOut: () => onProviderSelected(providers.elementAt(i)),
                      providerId: providers.elementAt(i).id,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A circle button that allows to choose a provider.
class _ProviderCircleButton extends ConsumerWidget {
  /// The provider id.
  final String providerId;

  /// The button size.
  final double size;

  /// The button padding.
  final EdgeInsets padding;

  /// Triggered when tapped on (only if user is logged out for the selected provider).
  final VoidCallback? onTapIfLoggedOut;

  /// Creates a new provider button instance.
  const _ProviderCircleButton({
    required this.providerId,
    required this.size,
    required this.padding,
    this.onTapIfLoggedOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    User? user = ref.watch(userProvider).value;
    bool isLoggedIn = user != null && user.hasAuthenticationProvider(providerId);
    Color? buttonColor = context.theme.buttonStyles.resolve({FButtonVariant.secondary}).base.decoration.base.color;
    Widget button = Tooltip(
      message: translations.authentication.authenticationProvider[providerId].name,
      child: ClickableButton.raw(
        onPress: isLoggedIn ? null : onTapIfLoggedOut,
        variant: .secondary,
        style: .delta(
          decoration: .delta(
            [
              .match(
                {.hovered},
                .boxDelta(color: buttonColor),
              ),
              .base(
                .boxDelta(color: buttonColor?.lighten(amount: 0.075)),
              ),
              .all(
                .boxDelta(
                  borderRadius: BorderRadius.circular(size + kBigSpace),
                ),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(kBigSpace),
          child: AuthenticationProviderImage(
            providerId: providerId,
            width: size,
            height: size,
          ),
        ),
      ),
    );
    if (isLoggedIn) {
      button = _AuthenticatedBadge(
        offset: Offset(-padding.right / 2, 0),
        child: button,
      );
    }
    return button;
  }
}

/// A button that allows to choose a provider.
class _ProviderButton extends ConsumerWidget {
  /// The provider id.
  final String providerId;

  /// Triggered when tapped on (only if user is logged out for the selected provider).
  final VoidCallback? onPressIfLoggedOut;

  /// Creates a new provider button instance.
  const _ProviderButton({
    required this.providerId,
    this.onPressIfLoggedOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    User? user = ref.watch(userProvider).value;
    String? title = translations.authentication.authenticationProvider[providerId].name;
    Widget child = title == null ? const SizedBox.shrink() : Text(title);
    if (user != null && user.hasAuthenticationProvider(providerId)) {
      child = _ButtonChildWithAuthenticatedBadge(
        child: child,
      );
    }
    return ClickableButton(
      variant: .secondary,
      onPress: onPressIfLoggedOut,
      prefix: AuthenticationProviderImage(
        providerId: providerId,
        width: 16,
        height: 16,
      ),
      child: child,
    );
  }
}

/// Allows to display an [_AuthenticatedBadge] in a [AppFilledButton].
class _ButtonChildWithAuthenticatedBadge extends StatelessWidget {
  /// The child.
  final Widget child;

  /// Creates a new button child with authenticated badge instance.
  const _ButtonChildWithAuthenticatedBadge({
    required this.child,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _AuthenticatedBadge(
      alignment: Alignment.topCenter,
      offset: Offset(constraints.maxWidth / 2 + 7, -7),
      child: child,
    ),
  );
}

/// Displays a badge indicating the user already has the current provider.
class _AuthenticatedBadge extends StatelessWidget {
  /// The badge offset.
  final Offset? offset;

  /// The alignment.
  final AlignmentGeometry? alignment;

  /// The widget child.
  final Widget child;

  /// Creates a new authenticated badge instance.
  const _AuthenticatedBadge({
    this.offset,
    this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Badge(
    offset: offset,
    alignment: alignment,
    label: const Icon(
      FIcons.check,
      color: Colors.white,
    ),
    backgroundColor: Colors.green.shade700,
    textColor: Colors.white,
    child: child,
  );
}
