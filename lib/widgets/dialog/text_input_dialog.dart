import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/password_verification/password_verification.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/form/password_form_field.dart';

/// Shows a dialog for prompting text.
class TextInputDialog extends StatefulWidget {
  /// The dialog title.
  final String title;

  /// The prompt message.
  final String message;

  /// Whether we're prompting for a password.
  final bool password;

  /// The form field validator.
  final FormFieldValidator<String>? validator;

  /// The keyboard type.
  final TextInputType? keyboardType;

  /// The initial value.
  final String initialValue;

  /// The input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// The text capitalization.
  final TextCapitalization? textCapitalization;

  /// Additional children to display.
  final List<Widget>? children;

  /// Creates a new text input dialog instance.
  const TextInputDialog({
    super.key,
    required this.title,
    required this.message,
    this.password = false,
    this.validator,
    this.keyboardType,
    String? initialValue,
    this.inputFormatters,
    this.textCapitalization,
    this.children,
  }) : initialValue = initialValue ?? '';

  @override
  State<StatefulWidget> createState() => _TextInputDialogState();

  /// Prompts for a string.
  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    required String message,
    bool password = false,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    String? initialValue,
    List<TextInputFormatter>? inputFormatters,
        TextCapitalization? textCapitalization,
    List<Widget>? children,
  }) => showFDialog<String>(
    context: context,
    builder: (context, style, animation) => TextInputDialog(
      title: title,
      message: message,
      password: password,
      validator: validator,
      keyboardType: keyboardType,
      initialValue: initialValue,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      children: children,
    ),
  );

  /// Validates the given mail.
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return null;
    }
    if (!RegExp(r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$').hasMatch(email)) {
      return translations.error.validation.email;
    }
    return null;
  }
}

/// The text input dialog state.
class _TextInputDialogState extends State<TextInputDialog> {
  /// The current value.
  late String value = widget.initialValue;

  /// The password text editing controller.
  late final TextEditingController valueController = TextEditingController(text: value)
    ..addListener(() {
      if (mounted) {
        onChanged(valueController.value.text);
      }
    });

  /// Whether the input is valid.
  late bool valid = widget.validator == null ? true : (widget.validator!.call(value) != null);

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.title),
    actions: [
      ClickableButton(
        onPress: valid ? (() => Navigator.pop(context, value)) : null,
        child: ButtonText(MaterialLocalizations.of(context).okButtonLabel),
      ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      Text(
        widget.message,
        textAlign: TextAlign.left,
      ),
      if (widget.children != null) ...widget.children!,
      if (widget.password)
        PasswordFormField(
          control: .managed(controller: valueController),
          autofocus: true,
          onSubmit: (value) => Navigator.pop(context, value),
          textInputAction: TextInputAction.go,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          autovalidateMode: AutovalidateMode.always,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization ?? .none,
        )
      else
        FTextFormField(
          control: .managed(controller: valueController),
          autofocus: true,
          onSubmit: (value) => Navigator.pop(context, value),
          textInputAction: TextInputAction.go,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          autovalidateMode: AutovalidateMode.always,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization ?? .none,
        ),
    ],
  );

  /// Triggered when changed.
  void onChanged(String newValue) {
    value = newValue;
    if (widget.validator != null) {
      bool result = widget.validator!(newValue) == null;
      setState(() => valid = result);
    }
  }
}

/// An input dialog for inputting and validating the master password.
class MasterPasswordInputDialog extends ConsumerStatefulWidget {
  /// The dialog title.
  final String title;

  /// The prompt message.
  final String message;

  /// Creates a new master password input dialog instance.
  MasterPasswordInputDialog({
    super.key,
    String? title,
    String? message,
  }) : title = title ?? translations.miscellaneous.masterPasswordDialog.title,
       message = message ?? translations.miscellaneous.masterPasswordDialog.message;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MasterPasswordInputDialogState();

  /// Prompts for a the master password.
  /// The returned String, if not null, is the correct master password.
  static Future<String?> prompt(
    BuildContext context, {
    String? title,
    String? message,
  }) => showFDialog<String>(
    context: context,
    builder: (context, style, animation) => MasterPasswordInputDialog(
      title: title,
      message: message,
    ),
  );

  /// Returns the string that validates the master password according to the given [validationResult].
  static String? validateMasterPassword(Result<bool> validationResult) {
    switch (validationResult) {
      case ResultSuccess<bool>(:final value):
        if (value) {
          return null;
        }
        return translations.error.validation.masterPassword;
      case ResultError<bool>(:final exception):
        return translations.error.generic.withException(exception: exception);
      default:
        break;
    }
    return translations.error.generic.tryAgain;
  }
}

/// The master password input dialog state.
class _MasterPasswordInputDialogState extends ConsumerState<MasterPasswordInputDialog> {
  /// The form field key.
  final GlobalKey<FormState> formFieldKey = GlobalKey<FormState>();

  /// The password.
  String password = '';

  /// The password text editing controller.
  late final TextEditingController passwordController = TextEditingController(text: password)
    ..addListener(() {
      if (mounted) {
        password = passwordController.value.text;
      }
    });

  /// The master password validation result.
  Result<bool> oldPasswordValidationResult = const ResultSuccess(value: false);

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.title),
    actions: [
      ClickableButton(
        onPress: onOkPress,
        child: ButtonText(MaterialLocalizations.of(context).okButtonLabel),
      ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      Text(
        widget.message,
        textAlign: TextAlign.left,
      ),
      Form(
        key: formFieldKey,
        child: PasswordFormField(
          control: .managed(controller: passwordController),
          autofocus: true,
          onSubmit: (value) => onOkPress(password: value),
          textInputAction: TextInputAction.go,
          validator: (_) => MasterPasswordInputDialog.validateMasterPassword(oldPasswordValidationResult),
          autovalidateMode: AutovalidateMode.disabled,
        ),
      ),
    ],
  );

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  /// Triggered when the ok button has been pressed.
  Future<void> onOkPress({String? password}) async {
    password ??= this.password;
    oldPasswordValidationResult = await (await ref.read(passwordVerificationProvider.future)).isPasswordValid(password);
    if (!formFieldKey.currentState!.validate() || !mounted) {
      return;
    }
    Navigator.pop(context, password);
  }
}
