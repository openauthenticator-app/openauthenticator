import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/form_label.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:open_authenticator/widgets/form/password_form_field.dart';

/// A form to prompt for the master password.
class MasterPasswordForm extends StatefulWidget {
  /// The form key. Allows to validate the input.
  final GlobalKey<FormState>? formKey;

  /// Triggered when the form has changed.
  final VoidCallback? onFormChanged;

  /// Triggered when the password has changed.
  /// This will either be a full password, or `null`.
  final ValueChanged<String?>? onChanged;

  /// The input text.
  final String inputText;

  /// The hint text.
  final String hintText;

  /// The default password.
  final String? defaultPassword;

  /// Creates a new master password form instance.
  MasterPasswordForm({
    super.key,
    this.formKey,
    this.onFormChanged,
    this.onChanged,
    String? inputText,
    String? hintText,
    this.defaultPassword,
  }) : inputText = inputText ?? translations.masterPassword.form.password.input,
       hintText = hintText ?? translations.masterPassword.form.password.hint;

  @override
  State<StatefulWidget> createState() => _MasterPasswordFormState();
}

/// The master password form state.
class _MasterPasswordFormState extends State<MasterPasswordForm> {
  /// The password input.
  late String passwordInput = widget.defaultPassword ?? '';

  /// The password text editing controller.
  late final TextEditingController passwordController = TextEditingController(text: passwordInput)
    ..addListener(() {
      if (mounted) {
        setState(() => passwordInput = passwordController.value.text);
        notifyChangesIfNeeded(password: passwordController.value.text);
      }
    });

  /// The confirmation input.
  late String confirmationInput = passwordInput;

  /// The confirmation text editing controller.
  late final TextEditingController confirmationController = TextEditingController(text: confirmationInput)
    ..addListener(() {
      if (mounted) {
        setState(() => confirmationInput = confirmationController.value.text);
        notifyChangesIfNeeded(confirmation: confirmationController.value.text);
      }
    });

  @override
  Widget build(BuildContext context) => Form(
    key: widget.formKey,
    onChanged: widget.onFormChanged,
    child: Column(
      children: [
        PasswordFormField(
          control: .managed(controller: passwordController),
          label: FormLabelWithIcon(
            icon: FIcons.rectangleEllipsis,
            text: widget.inputText,
          ),
          hint: widget.hintText,
          validator: validatePassword,
        ),
        SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: Text(
            translations.masterPassword.form.securityScore(score: '$securityScore/40'),
            style: context.theme.typography.sm.copyWith(
              fontWeight: .bold,
              color: securityScoreColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        PasswordFormField(
          control: .managed(controller: confirmationController),
          label: FormLabelWithIcon(
            icon: FIcons.check,
            text: translations.masterPassword.form.confirmation.input,
          ),
          hint: translations.masterPassword.form.confirmation.hint,
          validator: validateConfirmation,
        ),
      ],
    ),
  );

  @override
  void dispose() {
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  /// Calls [widget.onChanged] if the password has changed.
  void notifyChangesIfNeeded({String? password, String? confirmation}) {
    if (validatePassword(password ?? passwordInput) == null && validateConfirmation(confirmation ?? confirmationInput) == null) {
      widget.onChanged?.call(password ?? passwordInput);
    } else {
      widget.onChanged?.call(null);
    }
  }

  /// Validates the password input field.
  String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return translations.error.validation.empty;
    }
    return null;
  }

  /// Validates the confirmation field.
  String? validateConfirmation(String? value) {
    if (value != passwordInput) {
      return translations.error.validation.confirmation;
    }
    return null;
  }

  /// Returns the password strength. The result is a mark over 40.
  /// [Here](https://stackoverflow.com/a/32440338/3608831) is the algorithm used.
  int get securityScore {
    int score = 0;
    if (passwordInput.length >= 8) {
      score += 10;
    }
    if (passwordInput.contains(RegExp(r'[a-z]'))) {
      score += 5;
    }
    if (passwordInput.contains(RegExp(r'[A-Z]'))) {
      score += 5;
    }
    if (passwordInput.contains(RegExp(r'\d'))) {
      score += 5;
    }
    if (passwordInput.contains(RegExp(r'[!@#$%^&*(),.?":{}|]'))) {
      score += 10;
    }
    Set<String> uniqueChars = {};
    for (int i = 0; i < passwordInput.length; i++) {
      uniqueChars.add(passwordInput[i]);
    }
    if (uniqueChars.length >= 5) {
      score += 5;
    }
    return score;
  }

  /// Returns the color matching to the [securityScore].
  Color get securityScoreColor {
    int securityScore = this.securityScore;
    if (securityScore <= 5) {
      return context.theme.colors.error.darken(amount: 0.25);
    }
    if (securityScore <= 10) {
      return context.theme.colors.error.darken(amount: 0.125);
    }
    if (securityScore <= 15) {
      return context.theme.colors.error;
    }
    if (securityScore <= 20) {
      return Colors.orange.shade800;
    }
    if (securityScore <= 25) {
      return Colors.orange;
    }
    if (securityScore <= 30) {
      return context.theme.colors.primary.lighten(amount: 0.125);
    }
    if (securityScore <= 35) {
      return context.theme.colors.primary;
    }
    return context.theme.colors.primary.darken(amount: 0.125);
  }
}
