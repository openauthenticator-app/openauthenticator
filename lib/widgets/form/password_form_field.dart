import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

/// A form field for entering passwords.
class PasswordFormField extends StatefulWidget {
  /// The reveal button builder.
  final Widget Function(BuildContext, VoidCallback, bool) revealButtonBuilder;

  /// The control.
  final FTextFieldControl control;

  /// Whether this field is enabled.
  final bool enabled;

  /// Whether to auto focus this field.
  final bool autofocus;

  /// Triggered when the field has been submitted.
  final ValueChanged<String>? onSubmit;

  /// The text input action.
  final TextInputAction? textInputAction;

  /// The label widget.
  final Widget? label;

  /// The hint.
  final String? hint;

  /// The field validator.
  final FormFieldValidator<String>? validator;

  /// The keyboard type.
  final TextInputType? keyboardType;

  /// The auto validate mode.
  final AutovalidateMode autovalidateMode;

  /// The input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// The text capitalization.
  final TextCapitalization? textCapitalization;

  /// Creates a new password form field instance.
  const PasswordFormField({
    super.key,
    this.revealButtonBuilder = _defaultRevealButtonBuilder,
    this.control = const .managed(),
    this.enabled = true,
    this.autofocus = false,
    this.onSubmit,
    this.textInputAction,
    this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.autovalidateMode = .disabled,
    this.inputFormatters,
    this.textCapitalization,
  });

  @override
  State<StatefulWidget> createState() => _PasswordFormFieldState();

  /// The default reveal button builder.
  static Widget _defaultRevealButtonBuilder(BuildContext context, VoidCallback reveal, bool state) => IconButton(
    onPressed: reveal,
    icon: Icon(state ? FIcons.eyeClosed : FIcons.eye),
  );
}

/// The password form field.
class _PasswordFormFieldState extends State<PasswordFormField> {
  /// Whether the password is revealed.
  bool isRevealed = false;

  @override
  Widget build(BuildContext context) => FTextFormField(
    control: widget.control,
    obscureText: !isRevealed,
    enableSuggestions: false,
    autocorrect: false,
    autofocus: widget.autofocus,
    onSubmit: widget.onSubmit,
    textInputAction: widget.textInputAction,
    readOnly: !widget.enabled,
    suffixBuilder: (context, _, _) => widget.revealButtonBuilder(context, toggleObscuration, isRevealed),
    label: widget.label,
    hint: widget.hint,
    validator: widget.validator,
    keyboardType: widget.keyboardType,
    autovalidateMode: widget.autovalidateMode,
    inputFormatters: widget.inputFormatters,
    textCapitalization: widget.textCapitalization ?? .none,
  );

  /// Toggles the obscuration state.
  void toggleObscuration() {
    setState(() => isRevealed = !isRevealed);
  }
}
